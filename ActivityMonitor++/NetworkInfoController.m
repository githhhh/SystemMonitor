//
//  NetworkInfoController.m
//  ActivityMonitor++
//
//  Created by st on 23/05/2013.
//  Copyright (c) 2013 st. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <sys/types.h>
#import <sys/socket.h>
#import <sys/sysctl.h>
#import <netinet/in.h>
#import <net/if.h>
#import <net/if_dl.h>
#import "AMLog.h"
#import "AMUtils.h"
#import "AMDevice.h"
#import "NetworkBandwidth.h"
#import "NetworkInfoController.h"

@interface NetworkInfoController()
@property (strong, nonatomic) NetworkInfo   *networkInfo;
@property (strong, nonatomic) NSString      *currentInterface;
@property (assign, nonatomic) NSUInteger    bandwidthHistorySize;

@property (strong, nonatomic) NSTimer       *networkBandwidthUpdateTimer;
- (void)networkBandwidthUpdateCB:(NSNotification*)notification;

@property (assign, nonatomic) SCNetworkReachabilityRef reachability;

- (void)initReachability;
- (BOOL)internetConnected;
- (NSString*)internetInterface;
- (NSString*)readableCurrentInterface;
- (void)reachabilityStatusChangedCB;

- (NetworkInfo*)populateNetworkInfo;

- (NSString*)getExternalIPAddress;
- (NSString*)getInternalIPAddressOfInterface:(NSString*)interface;
- (NSString*)getNetmaskOfInterface:(NSString*)interface;
- (NSString*)getBroadcastAddressOfInterface:(NSString*)interface;
- (NSString*)getMacAddressOfInterface:(NSString*)interface;
- (NetworkBandwidth*)getNetworkBandwidth;

- (void)pushNetworkBandwidth:(NetworkBandwidth*)bandwidth;
@end

@implementation NetworkInfoController
@synthesize delegate;
@synthesize networkBandwidthHistory;

@synthesize networkInfo;
@synthesize currentInterface;
@synthesize networkBandwidthUpdateTimer;

@synthesize reachability;

static NSString *kInterfaceWiFi = @"en0";
static NSString *kInterfaceWWAN = @"pdp_ip0";
static NSString *kInterfaceNone = @"";

#pragma mark - override

- (id)init
{
    if (self = [super init])
    {
        self.networkInfo = [[NetworkInfo alloc] init];
        self.networkBandwidthHistory = [[NSMutableArray alloc] init];
        self.networkBandwidthHistorySize = kDefaultDataHistorySize;
    }
    return self;
}

- (void)dealloc
{
    if (self.reachability)
    {
        CFRelease(self.reachability);
    }
}

#pragma mark - public

- (NetworkInfo*)getNetworkInfo
{
    return [self populateNetworkInfo];
}

- (void)startNetworkBandwidthUpdatesWithFrequency:(NSUInteger)frequency
{
    [self stopNetworkBandwidthUpdates];
    self.networkBandwidthUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f / frequency
                                                                        target:self
                                                                      selector:@selector(networkBandwidthUpdateCB:)
                                                                      userInfo:nil
                                                                       repeats:YES];
    [self.networkBandwidthUpdateTimer fire];
}

- (void)stopNetworkBandwidthUpdates
{
    [self.networkBandwidthUpdateTimer invalidate];
    self.networkBandwidthUpdateTimer = nil;
}

- (void)setNetworkBandwidthHistorySize:(NSUInteger)size
{
    self.bandwidthHistorySize = size;
}

#pragma mark - private

- (void)networkBandwidthUpdateCB:(NSNotification*)notification
{
    NetworkBandwidth *bandwidth = [self getNetworkBandwidth];
    [self pushNetworkBandwidth:bandwidth];
    [self.delegate networkBandwidthUpdated:bandwidth];
}

static void reachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
    assert(info != NULL);
    assert([(__bridge NSObject*)(info) isKindOfClass:[NetworkInfoController class]]);
    
    NetworkInfoController *networkCtrl = (__bridge NetworkInfoController*)(info);
    [networkCtrl reachabilityStatusChangedCB];
}

- (void)initReachability
{
    if (!self.reachability)
    {
        struct sockaddr_in hostAddress;
        bzero(&hostAddress, sizeof(hostAddress));
        hostAddress.sin_len = sizeof(hostAddress);
        hostAddress.sin_family = AF_INET;
        
        self.reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)&hostAddress);
    
        if (!self.reachability)
        {
            AMWarn(@"reachability create has failed.");
            return;
        }
        
        BOOL result;
        SCNetworkReachabilityContext context = { 0, (__bridge void *)self, NULL, NULL, NULL };
        
        result = SCNetworkReachabilitySetCallback(self.reachability, reachabilityCallback, &context);
        if (!result)
        {
            AMWarn(@"error setting reachability callback.");
            return;
        }
        
        result = SCNetworkReachabilityScheduleWithRunLoop(self.reachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        if (!result)
        {
            AMWarn(@"error setting runloop mode.");
            return;
        }
    }
}

- (BOOL)internetConnected
{
    if (!self.reachability)
    {
        [self initReachability];
    }
    
    if (!self.reachability)
    {
        AMWarn(@"cannot initialize reachability.");
        return NO;
    }
    
    SCNetworkReachabilityFlags flags;
    if (!SCNetworkReachabilityGetFlags(self.reachability, &flags))
    {
        AMWarn(@"failed to retrieve reachability flags.");
        return NO;
    }

    BOOL isReachable = (flags & kSCNetworkReachabilityFlagsReachable);
    BOOL noConnectionRequired = !(flags & kSCNetworkReachabilityFlagsConnectionRequired);
    
    if (flags & kSCNetworkReachabilityFlagsIsWWAN)
    {
        noConnectionRequired = YES;
    }
    
    return ((isReachable && noConnectionRequired) ? YES : NO);
}

- (NSString*)internetInterface
{
    if (!self.reachability)
    {
        [self initReachability];
    }
    
    if (!self.reachability)
    {
        AMWarn(@"cannot initialize reachability.");
        return kInterfaceNone;
    }
    
    SCNetworkReachabilityFlags flags;
    if (!SCNetworkReachabilityGetFlags(self.reachability, &flags))
    {
        AMWarn(@"failed to retrieve reachability flags.");
        return kInterfaceNone;
    }

    if ((flags & kSCNetworkFlagsReachable) &&
        (!(flags & kSCNetworkReachabilityFlagsIsWWAN)))
    {
        return kInterfaceWiFi;
    }
    
    if ((flags & kSCNetworkReachabilityFlagsReachable) &&
        (flags & kSCNetworkReachabilityFlagsIsWWAN))
    {
        return kInterfaceWWAN;
    }
    
    return kInterfaceNone;
}

- (NSString*)readableCurrentInterface
{
    if ([self.currentInterface isEqualToString:kInterfaceWiFi])
    {
        return @"WiFi";
    }
    else if ([self.currentInterface isEqualToString:kInterfaceWWAN])
    {
        return @"Cellular";
    }
    else
    {
        return @"Not Connected";
    }
}

- (void)reachabilityStatusChangedCB
{
    [self populateNetworkInfo];
    [self.delegate networkStatusUpdated];
}

- (NetworkInfo*)populateNetworkInfo
{
    self.currentInterface = [self internetInterface];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.networkInfo.externalIPAddress = @"-"; // Placeholder while fetching.
        self.networkInfo.externalIPAddress = [self getExternalIPAddress];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate networkExternalIPAddressUpdated];
        });
    });
    
    self.networkInfo.readableInterface = [self readableCurrentInterface];
    self.networkInfo.internalIPAddress = [self getInternalIPAddressOfInterface:self.currentInterface];
    self.networkInfo.netmask = [self getNetmaskOfInterface:self.currentInterface];
    self.networkInfo.broadcastAddress = [self getBroadcastAddressOfInterface:self.currentInterface];
    self.networkInfo.macAddress = [self getMacAddressOfInterface:self.currentInterface];
    return self.networkInfo;
}

- (NSString*)getExternalIPAddress
{
    NSString *ip = @"-";
    
    if (![self internetConnected])
    {
        return ip;
    }
    
    NSURL *url = [NSURL URLWithString:@"http://www.dyndns.org/cgi-bin/check_ip.cgi"];
    if (!url)
    {
        AMWarn(@"failed to create NSURL.");
        return ip;
    }

    NSError *error = nil;
    NSString *ipHtml = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
    if (error)
    {
        AMWarn(@"failed to fetch IP content: %@", error.description);
        return ip;
    }

    NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})"
                                                                            options:NSRegularExpressionCaseInsensitive
                                                                              error:&error];
    if (error)
    {
        AMWarn(@"failed to create regexp: %@", error.description);
        return ip;
    }
    NSRange regexpRange = [regexp rangeOfFirstMatchInString:ipHtml options:NSMatchingReportCompletion range:NSMakeRange(0, ipHtml.length)];
    NSString *match = [ipHtml substringWithRange:regexpRange];
    
    if (match && match.length > 0)
    {
        ip = [NSString stringWithString:match];
    }
    
    return ip;
}

- (NSString*)getInternalIPAddressOfInterface:(NSString*)interface
{    
    NSString *address = @"-";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    
    if (!interface || interface.length == 0)
    {
        return address;
    }
    
    if (getifaddrs(&interfaces) == 0)
    {
        temp_addr = interfaces;
        
        while (temp_addr != NULL)
        {
            if (temp_addr->ifa_addr->sa_family == AF_INET)
            {
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:interface])
                {
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in*)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    freeifaddrs(interfaces);
    return address;
}

- (NSString*)getNetmaskOfInterface:(NSString*)interface
{
    NSString *netmask = @"-";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    
    if (!interface || interface.length == 0)
    {
        return netmask;
    }
    
    if (getifaddrs(&interfaces) == 0)
    {
        temp_addr = interfaces;
        
        while (temp_addr != NULL)
        {
            if (temp_addr->ifa_addr->sa_family == AF_INET)
            {
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:interface])
                {
                    netmask = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in*)temp_addr->ifa_netmask)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    freeifaddrs(interfaces);
    return netmask;
}

- (NSString*)getBroadcastAddressOfInterface:(NSString*)interface
{
    NSString *address = @"-";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    
    if (!interface || interface.length == 0)
    {
        return address;
    }
    
    if (getifaddrs(&interfaces) == 0)
    {
        temp_addr = interfaces;
        
        while (temp_addr != NULL)
        {
            if (temp_addr->ifa_addr->sa_family == AF_INET)
            {
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:interface])
                {
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in*)temp_addr->ifa_dstaddr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    freeifaddrs(interfaces);
    return address;
}

- (NSString*)getMacAddressOfInterface:(NSString*)interface
{
    NSString            *mac = @"-";
    int                 mib[6];
    char                *msgBuffer = NULL;
    size_t              length;
    unsigned char       macAddress[6];
    struct if_msghdr    *interfaceMsgStruct;
    struct sockaddr_dl  *socketStruct;
    
    if (!interface || interface.length == 0)
    {
        return mac;
    }
    
    mib[0] = CTL_NET;       // Network subsystem.
    mib[1] = AF_ROUTE;      // Routing table info
    mib[2] = 0;
    mib[3] = AF_LINK;       // Link layer information
    mib[4] = NET_RT_IFLIST; // All configured interfaces
    
    if ((mib[5] = if_nametoindex([interface cStringUsingEncoding:NSASCIIStringEncoding])) == 0)
    {
        AMWarn(@"if_nametoindex() has failed for interface %@.", interface);
        return mac;
    }
    else
    {
        if (sysctl(mib, 6, NULL, &length, NULL, 0) < 0)
        {
            AMWarn(@"sysctl() has failed. (1)");
            return mac;
        }
        else
        {
            msgBuffer = malloc(length);
            if (!msgBuffer)
            {
                AMWarn(@"malloc() has failed.");
                return mac;
            }
            
            if (sysctl(mib, 6, msgBuffer, &length, NULL, 0) < 0)
            {
                AMWarn(@"sysctl() has failed. (2)");
                return mac;
            }
        }
    }
    
    interfaceMsgStruct = (struct if_msghdr*) msgBuffer;
    socketStruct = (struct sockaddr_dl*) (interfaceMsgStruct + 1);
    memcpy(&macAddress, socketStruct->sdl_data + socketStruct->sdl_nlen, 6);
    mac = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
           macAddress[0], macAddress[1], macAddress[2], macAddress[3], macAddress[4], macAddress[5]];
    free(msgBuffer);
    
    return mac;
}

- (NetworkBandwidth*)getNetworkBandwidth
{
    NetworkBandwidth *bandwidth = [[NetworkBandwidth alloc] init];
    bandwidth.interface = self.currentInterface;
    
    int mib[] = {
        CTL_NET,
        PF_ROUTE,
        0,
        0,
        NET_RT_IFLIST2,
        0
    };
    
    size_t len;
    if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0)
    {
        AMWarn(@"sysctl failed (1)");
        return bandwidth;
    }
    char *buf = malloc(len);
    if (sysctl(mib, 6, buf, &len, NULL, 0) < 0)
    {
        AMWarn(@"sysctl failed (2)");
        return bandwidth;
    }
    char *lim = buf + len;
    char *next = NULL;
    for (next = buf; next < lim; )
    {
        struct if_msghdr *ifm = (struct if_msghdr *)next;
        next += ifm->ifm_msglen;
        
/* iOS does't include <net/route.h>, so we define our own macros. */
#define RTM_IFINFO2 0x12
        if (ifm->ifm_type == RTM_IFINFO2)
#undef RTM_IFINFO2
        {
            struct if_msghdr2 *if2m = (struct if_msghdr2 *)ifm;
            
            char ifnameBuf[IF_NAMESIZE];
            if (!if_indextoname(ifm->ifm_index, ifnameBuf))
            {
                AMWarn(@"if_indextoname() has failed.");
                continue;
            }
            NSString *ifname = [NSString stringWithCString:ifnameBuf encoding:NSASCIIStringEncoding];
            
            if ([ifname isEqualToString:kInterfaceWiFi])
            {
                bandwidth.totalWiFiSent += B_TO_KB(if2m->ifm_data.ifi_ibytes);
                bandwidth.totalWiFiReceived += B_TO_KB(if2m->ifm_data.ifi_obytes);
            }
            else if ([ifname isEqualToString:kInterfaceWWAN])
            {
                bandwidth.totalWWANSent += B_TO_KB(if2m->ifm_data.ifi_ibytes);
                bandwidth.totalWWANReceived += B_TO_KB(if2m->ifm_data.ifi_obytes);
            }
        }
    }
    
    if (self.networkBandwidthHistory.count > 0)
    {
        NetworkBandwidth *prevBandwidth = [self.networkBandwidthHistory lastObject];
        if ([prevBandwidth.interface isEqualToString:self.currentInterface])
        {
            if ([self.currentInterface isEqualToString:kInterfaceWiFi])
            {
                bandwidth.sent = B_TO_KB(bandwidth.totalWiFiSent - prevBandwidth.totalWiFiSent);
                bandwidth.received = B_TO_KB(bandwidth.totalWiFiReceived - prevBandwidth.totalWiFiReceived);
            }
            else if ([self.currentInterface isEqualToString:kInterfaceWWAN])
            {
                bandwidth.sent = B_TO_KB(bandwidth.totalWWANSent - prevBandwidth.totalWWANSent);
                bandwidth.received = B_TO_KB(bandwidth.totalWWANReceived - prevBandwidth.totalWWANReceived);
            }
        }
    }
    
    return bandwidth;
}

- (void)pushNetworkBandwidth:(NetworkBandwidth*)bandwidth
{
    [self.networkBandwidthHistory addObject:bandwidth];
    
    while (self.networkBandwidthHistory.count > self.bandwidthHistorySize)
    {
        [self.networkBandwidthHistory removeObjectAtIndex:0];
    }
}

@end
