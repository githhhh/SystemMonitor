//
//  RootTableViewController.h
//  System Monitor
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2013 Arvydas Sidorenko
//

#import <UIKit/UIKit.h>

typedef enum {
    VIEW_CTRL_GENERAL=0,
    VIEW_CTRL_CPU,
    VIEW_CTRL_PROCESSES,
    VIEW_CTRL_RAM,
    VIEW_CTRL_GPU,
    VIEW_CTRL_NETWORK,
    VIEW_CTRL_CONNECTIONS,
    VIEW_CTRL_STORAGE,
    VIEW_CTRL_BATTERY,
    VIEW_CTRL_RATE_US,
    VIEW_CTRL_MAX
} ViewCtrl_t;

static NSString *ViewCtrlIdentifiers[] = {
    [VIEW_CTRL_GENERAL]     = @"GeneralViewController",
    [VIEW_CTRL_CPU]         = @"CPUViewController",
    [VIEW_CTRL_PROCESSES]   = @"ProcessViewController",
    [VIEW_CTRL_RAM]         = @"RAMViewController",
    [VIEW_CTRL_GPU]         = @"GPUViewController",
    [VIEW_CTRL_NETWORK]     = @"NetworkViewController",
    [VIEW_CTRL_CONNECTIONS] = @"ConnectionViewController",
    [VIEW_CTRL_STORAGE]     = @"StorageViewController",
    [VIEW_CTRL_BATTERY]     = @"BatteryViewController",
    [VIEW_CTRL_RATE_US]     = nil
};

static NSString *CellImageFilenames[] = {
    [VIEW_CTRL_GENERAL]     = @"GeneralIcon-normal.png",
    [VIEW_CTRL_CPU]         = @"CpuIcon-normal.png",
    [VIEW_CTRL_PROCESSES]   = @"ProcessesIcon-normal.png",
    [VIEW_CTRL_RAM]         = @"RamIcon-normal.png",
    [VIEW_CTRL_GPU]         = @"GpuIcon-normal.png",
    [VIEW_CTRL_NETWORK]     = @"NetworkIcon-normal.png",
    [VIEW_CTRL_CONNECTIONS] = @"ConnectionsIcon-normal.png",
    [VIEW_CTRL_STORAGE]     = @"StorageIcon-normal.png",
    [VIEW_CTRL_BATTERY]     = @"BatteryIcon-normal.png",
    [VIEW_CTRL_RATE_US]     = @"GithubIcon.png"
};

static NSString *CellHighlightImageFilenames[] = {
    [VIEW_CTRL_GENERAL]     = @"GeneralIcon-highlight.png",
    [VIEW_CTRL_CPU]         = @"CpuIcon-highlight.png",
    [VIEW_CTRL_PROCESSES]   = @"ProcessesIcon-highlight.png",
    [VIEW_CTRL_RAM]         = @"RamIcon-highlight.png",
    [VIEW_CTRL_GPU]         = @"GpuIcon-highlight.png",
    [VIEW_CTRL_NETWORK]     = @"NetworkIcon-highlight.png",
    [VIEW_CTRL_CONNECTIONS] = @"ConnectionsIcon-highlight.png",
    [VIEW_CTRL_STORAGE]     = @"StorageIcon-highlight.png",
    [VIEW_CTRL_BATTERY]     = @"BatteryIcon-highlight.png",
    [VIEW_CTRL_RATE_US]     = @"GithubIcon.png"
};

@interface RootTableViewController : UITableViewController
- (void)switchView:(ViewCtrl_t)viewCtrl;
@end
