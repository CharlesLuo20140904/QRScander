//
//  ViewController.m
//  QRScander
//
//  Created by yinmi on 2019/4/30.
//  Copyright © 2019 charles. All rights reserved.
//

#import "ViewController.h"
#import "ScanViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}


- (IBAction)clickScanBtn:(UIButton *)sender {
    ScanViewController *vc = [[ScanViewController alloc] init];
    vc.resultBlock = ^(NSString *message) {
        
    };
    [self.navigationController pushViewController:vc animated:YES];
}


@end
