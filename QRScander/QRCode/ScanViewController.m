//
//  ScanViewController.m
//  HLRCode
//
//  Created by 郝靓 on 2018/7/9.
//  Copyright © 2018年 郝靓. All rights reserved.
//

#import "ScanViewController.h"
#define Height [UIScreen mainScreen].bounds.size.height
#define Width [UIScreen mainScreen].bounds.size.width
#define XCenter self.view.center.x
#define YCenter self.view.center.y

#define SHeight 20

#define SWidth (XCenter+30)

@interface ScanViewController ()<UINavigationControllerDelegate>
{
    NSTimer *_timer;
    int num;
    BOOL upOrDown;
    
}
@property (nonatomic, weak) UINavigationController *navController;
@property (nonatomic, weak) id<UIGestureRecognizerDelegate> popDelegate;
@end

@implementation ScanViewController

#pragma mark ===========懒加载===========
//device
- (AVCaptureDevice *)device
{
    if (_device == nil) {
        //AVMediaTypeVideo是打开相机
        //AVMediaTypeAudio是打开麦克风
        _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    return _device;
}
//input
- (AVCaptureDeviceInput *)input
{
    if (_input == nil) {
        _input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    }
    return _input;
}
//output  --- output如果不打开就无法输出扫描得到的信息
// 设置输出对象解析数据时感兴趣的范围
// 默认值是 CGRect(x: 0, y: 0, width: 1, height: 1)
// 通过对这个值的观察, 我们发现传入的是比例
// 注意: 参照是以横屏的左上角作为, 而不是以竖屏
//        out.rectOfInterest = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
- (AVCaptureMetadataOutput *)output
{
    if (_output == nil) {
        _output = [[AVCaptureMetadataOutput alloc]init];
        [_output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        //限制扫描区域(上下左右)
        [_output setRectOfInterest:[self rectOfInterestByScanViewRect:_imageView.frame]];
    }
    return _output;
}
- (CGRect)rectOfInterestByScanViewRect:(CGRect)rect {
    CGFloat width = CGRectGetWidth(self.view.frame);
    CGFloat height = CGRectGetHeight(self.view.frame);
    
    CGFloat x = (height - CGRectGetHeight(rect)) / 2 / height;
    CGFloat y = (width - CGRectGetWidth(rect)) / 2 / width;
    
    CGFloat w = CGRectGetHeight(rect) / height;
    CGFloat h = CGRectGetWidth(rect) / width;
    
    return CGRectMake(x, y, w, h);
}

//session
- (AVCaptureSession *)session
{
    if (_session == nil) {
        //session
        _session = [[AVCaptureSession alloc]init];
        [_session setSessionPreset:AVCaptureSessionPresetHigh];
        if ([_session canAddInput:self.input]) {
            [_session addInput:self.input];
        }
        if ([_session canAddOutput:self.output]) {
            [_session addOutput:self.output];
        }
    }
    return _session;
}
//preview
- (AVCaptureVideoPreviewLayer *)preview
{
    if (_preview == nil) {
        _preview = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    }
    return _preview;
}

#pragma mark ==========ViewDidLoad==========
- (void)viewDidLoad
{
    //1 判断是否存在相机
    if (self.device == nil) {
        [self showAlertViewWithMessage:@"未检测到相机"];
        
        return;
    }
    self.view.backgroundColor = [UIColor whiteColor];
//    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"相册" style:UIBarButtonItemStylePlain target:self action:@selector(chooseButtonClick)];
    //打开定时器，开始扫描
    [self addTimer];
    
    //界面初始化
    [self interfaceSetup];
    
    //初始化扫描
    [self scanSetup];
    
}

#pragma mark ==========初始化工作在这里==========
- (void)dealloc {
    [_timer invalidate];
    _timer = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.delegate = self;
    self.navController = self.navigationController;
    [self.navController setNavigationBarHidden:YES animated:animated];
    [self starScan];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
}

- (void)viewDidDisappear:(BOOL)animated
{
    //视图退出，关闭扫描
    [self.session stopRunning];
    //关闭定时器
    [_timer setFireDate:[NSDate distantFuture]];
}

//界面初始化
- (void)interfaceSetup
{

    //1 添加扫描框
    [self addImageView];
    
    //添加模糊效果
    [self setOverView];
    //添加开始扫描按钮
//    [self addStartButton];
    //返回按钮
    [self backButtonSetup];
    //顶部自定义的title
    [self headerTitleSetup];
    //灯光按钮和相册按钮
    [self btnViewSetup];
}

//添加扫描框
- (void)addImageView
{
    _imageView = [[UIImageView alloc]initWithFrame:CGRectMake((Width-SWidth)/2, (Height-SWidth)/2-40, SWidth, SWidth)];
    //显示扫描框
    _imageView.image = [UIImage imageNamed:@"scanscanBg.png"];
    [self.view addSubview:_imageView];
    _line = [[UIImageView alloc]initWithFrame:CGRectMake(CGRectGetMinX(_imageView.frame)+5, CGRectGetMinY(_imageView.frame)+5, CGRectGetWidth(_imageView.frame), 3)];
    _line.image = [UIImage imageNamed:@"scanLine"];
    [self.view addSubview:_line];
    
    UILabel * lable = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 40)];
    [lable setText:@"将二维码放入框内，自动识别"];
    lable.textAlignment = NSTextAlignmentCenter;
    lable.textColor = [UIColor whiteColor];
    lable.font = [UIFont systemFontOfSize:14];
    lable.center = CGPointMake(_imageView.center.x , _imageView.center.y+ SWidth/2 + 30);
    [self.view addSubview:lable];
}

//初始化扫描配置
- (void)scanSetup
{
    //2 添加预览图层
    self.preview.frame = self.view.bounds;
    self.preview.videoGravity = AVLayerVideoGravityResize;
    [self.view.layer insertSublayer:self.preview atIndex:0];
    
    //3 设置输出能够解析的数据类型
    //注意:设置数据类型一定要在输出对象添加到回话之后才能设置
    [self.output setMetadataObjectTypes:@[AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code, AVMetadataObjectTypeQRCode]];
    
    //高质量采集率
    [self.session setSessionPreset:AVCaptureSessionPresetHigh];
    
    //4 开始扫描
    [self.session startRunning];
    
}

//返回按钮
-(void)backButtonSetup{
    UIButton *returnBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    returnBtn.frame = CGRectMake(10, 18, 40, 40);
    [returnBtn setImage:[UIImage imageNamed:@"back_w"] forState:UIControlStateNormal];
    [returnBtn addTarget:self action:@selector(backVC) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:returnBtn];
}

-(void)backVC{
    [self.navigationController popViewControllerAnimated:YES];
}

//自定义title
-(void)headerTitleSetup{
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 18, 150, 40)];
    titleLabel.center = CGPointMake(Width/2.0, 38.0);
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.text = @"扫码";
    [self.view addSubview:titleLabel];
}

//灯光按钮、相册按钮
-(void)btnViewSetup{
    UIView *bgView = [[UIView alloc] initWithFrame:CGRectMake((Width-275.0)/2.0, (Height-SWidth)/2+60+SWidth, 275, 70)];
    bgView.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5];
    bgView.layer.cornerRadius = 4;
    
    UIButton *lightBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    lightBtn.frame = CGRectMake(55, 10, 28, 50);
    [lightBtn setImage:[UIImage imageNamed:@"light_default_btn"] forState:UIControlStateNormal];
    [lightBtn setImage:[UIImage imageNamed:@"light_select_btn"] forState:UIControlStateSelected];
    [lightBtn setTitle:@"灯光" forState:UIControlStateNormal];
    lightBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [lightBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [lightBtn setTitleColor:[UIColor colorWithRed:38.0/255.0 green:209.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateSelected];
    [lightBtn addTarget:self action:@selector(openLight:) forControlEvents:UIControlEventTouchUpInside];
    [lightBtn setContentHorizontalAlignment:UIControlContentHorizontalAlignmentCenter];
    [lightBtn setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
    [lightBtn setTitleEdgeInsets:UIEdgeInsetsMake(35.0, -29.0, 0.0, 0.0)];
    [lightBtn setImageEdgeInsets:UIEdgeInsetsMake(0.0, 0.0, 23.0, 0.0)];
    [bgView addSubview:lightBtn];
    
    UIButton *photoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    photoBtn.frame = CGRectMake(192, 10, 28, 50);
    [photoBtn setImage:[UIImage imageNamed:@"album_select_default"] forState:UIControlStateNormal];
    [photoBtn setTitle:@"相册" forState:UIControlStateNormal];
    photoBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [photoBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [photoBtn setTitleColor:[UIColor colorWithRed:38.0/255.0 green:209.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateSelected];
    [photoBtn addTarget:self action:@selector(chooseButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [photoBtn setContentHorizontalAlignment:UIControlContentHorizontalAlignmentCenter];
    [photoBtn setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
    [photoBtn setTitleEdgeInsets:UIEdgeInsetsMake(35.0, -30.0, 0.0, 0.0)];
    [photoBtn setImageEdgeInsets:UIEdgeInsetsMake(0.0, 0.0, 23.0, 0.0)];
    [bgView addSubview:photoBtn];
    
    [self.view addSubview:bgView];
}

-(void)openLight:(UIButton *)btn{
    btn.selected = !btn.selected;
    [self systemLightSwitch:btn.selected];
}

//提示框alert
- (void)showAlertViewWithMessage:(NSString *)message
{
    //弹出提示框后，关闭扫描
    [self.session stopRunning];
    //弹出alert，关闭定时器
    [_timer setFireDate:[NSDate distantFuture]];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"扫描结果" message:[NSString stringWithFormat:@"%@",message] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"完成" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
      
        
        
        //点击alert，开始扫描
        [self.session startRunning];
        //开启定时器
        [_timer setFireDate:[NSDate distantPast]];
    }]];
    [self presentViewController:alert animated:true completion:^{
        
    }];
    
}

- (void)showsScanResult:(NSString *)message {
    //弹出提示框后，关闭扫描
    [self.session stopRunning];
    //弹出alert，关闭定时器
    [_timer setFireDate:[NSDate distantFuture]];
    _resultBlock(message);
}

//打开系统相册
- (void)chooseButtonClick
{
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        //关闭扫描
        [self stopScan];
        
        //1 弹出系统相册
        UIImagePickerController *pickVC = [[UIImagePickerController alloc]init];
        //2 设置照片来源
        /**
         UIImagePickerControllerSourceTypePhotoLibrary,相册
         UIImagePickerControllerSourceTypeCamera,相机
         UIImagePickerControllerSourceTypeSavedPhotosAlbum,照片库
         */
        
        pickVC.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
        //3 设置代理
        pickVC.delegate = self;
        //4.转场动画
        self.modalTransitionStyle=UIModalTransitionStyleFlipHorizontal;
        [self presentViewController:pickVC animated:YES completion:nil];
    }
    else
    {
        [self showAlertViewWithTitle:@"打开失败" withMessage:@"相册打开失败。设备不支持访问相册，请在设置->隐私->照片中进行设置！"];
    }
    
}
//从相册中选取照片&读取相册二维码信息
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    //1 获取选择的图片
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    //初始化一个监听器
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{CIDetectorAccuracy : CIDetectorAccuracyHigh}];
    [picker dismissViewControllerAnimated:YES completion:^{
        //监测到的结果数组
        NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage:image.CGImage]];
        if (features.count >= 1) {
            //结果对象
            CIQRCodeFeature *feature = [features objectAtIndex:0];
            NSString *scannedResult = feature.messageString;
            self.resultBlock(scannedResult);
//            [self showAlertViewWithTitle:@"读取相册二维码" withMessage:scannedResult];
        }
        else
        {
            [self showAlertViewWithTitle:@"读取相册二维码" withMessage:@"读取失败"];
        }
    }];
    
}

#pragma mark ===========重启扫描&闪光灯===========
//添加开始扫描按钮
- (void)addStartButton
{
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeCustom];
    startButton.frame = CGRectMake(60, 420, 80, 40);
    startButton.backgroundColor = [UIColor orangeColor];
    [startButton addTarget:self action:@selector(startButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [startButton setTitle:@"扫描" forState:UIControlStateNormal];
    [self.view addSubview:startButton];
}

- (void)startButtonClick
{
    //清除imageView上的图片
    self.imageView.image = [UIImage imageNamed:@""];
    //开始扫描
    [self starScan];
    
}


- (void)systemLightSwitch:(BOOL)open
{
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([device hasTorch]) {
        [device lockForConfiguration:nil];
        if (open) {
            [device setTorchMode:AVCaptureTorchModeOn];
        } else {
            [device setTorchMode:AVCaptureTorchModeOff];
        }
        [device unlockForConfiguration];
    }
}

#pragma mark ===========添加提示框===========
//提示框alert
- (void)showAlertViewWithTitle:(NSString *)aTitle withMessage:(NSString *)aMessage
{
    
    //弹出提示框后，关闭扫描
    [self.session stopRunning];
    //弹出alert，关闭定时器
    [_timer setFireDate:[NSDate distantFuture]];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:aTitle message:[NSString stringWithFormat:@"%@",aMessage] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        //点击alert，开始扫描
        [self.session startRunning];
        //开启定时器
        [_timer setFireDate:[NSDate distantPast]];
    }]];
    [self presentViewController:alert animated:true completion:^{
        
    }];
    
}


#pragma mark ===========扫描的代理方法===========
//得到扫描结果
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if ([metadataObjects count] > 0) {
        AVMetadataMachineReadableCodeObject *metadataObject = [metadataObjects objectAtIndex:0];
        if ([metadataObject isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
            NSString *stringValue = [metadataObject stringValue];
            if (stringValue != nil) {
                [self.session stopRunning];
                //扫描结果
             
                NSLog(@"%@",stringValue);
                
                
                // 结果的弹框
//                [self showAlertViewWithMessage:stringValue];
                [self showsScanResult:stringValue];
            }
        }
        
    }
}


#pragma mark ============添加模糊效果============
- (void)setOverView {
    CGFloat width = CGRectGetWidth(self.view.frame);
    CGFloat height = CGRectGetHeight(self.view.frame);
    
    CGFloat x = CGRectGetMinX(_imageView.frame);
    CGFloat y = CGRectGetMinY(_imageView.frame);
    CGFloat w = CGRectGetWidth(_imageView.frame);
    CGFloat h = CGRectGetHeight(_imageView.frame);
    
    [self creatView:CGRectMake(0, 0, width, y)];
    [self creatView:CGRectMake(0, y, x, h)];
    [self creatView:CGRectMake(0, y + h, width, height - y - h)];
    [self creatView:CGRectMake(x + w, y, width - x - w, h)];
}

- (void)creatView:(CGRect)rect {
    CGFloat alpha = 0.5;
    UIColor *backColor = [UIColor blackColor];
    UIView *view = [[UIView alloc] initWithFrame:rect];
    view.backgroundColor = backColor;
    view.alpha = alpha;
    [self.view addSubview:view];
}

#pragma mark ============添加扫描效果============

- (void)addTimer
{
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.008 target:self selector:@selector(timerMethod) userInfo:nil repeats:YES];
}
//控制扫描线上下滚动
- (void)timerMethod
{
    if (upOrDown == NO) {
        num ++;
        _line.frame = CGRectMake(CGRectGetMinX(_imageView.frame)+5, CGRectGetMinY(_imageView.frame)+5+num, CGRectGetWidth(_imageView.frame)-10, 3);
        if (num == (int)(CGRectGetHeight(_imageView.frame)-10)) {
            upOrDown = YES;
        }
    }
    else
    {
        num --;
        _line.frame = CGRectMake(CGRectGetMinX(_imageView.frame)+5, CGRectGetMinY(_imageView.frame)+5+num, CGRectGetWidth(_imageView.frame)-10, 3);
        if (num == 0) {
            upOrDown = NO;
        }
    }
}
//暂定扫描
- (void)stopScan
{
    //弹出提示框后，关闭扫描
    [self.session stopRunning];
    //弹出alert，关闭定时器
    [_timer setFireDate:[NSDate distantFuture]];
    //隐藏扫描线
    _line.hidden = YES;
}
- (void)starScan
{
    //开始扫描
    [self.session startRunning];
    //打开定时器
    [_timer setFireDate:[NSDate distantPast]];
    //显示扫描线
    _line.hidden = NO;
}

#pragma mark - navigationController代理
- (void)navigationController:(UINavigationController*)navigationController willShowViewController:(UIViewController*)viewController animated:(BOOL)animated
{
    if(viewController == self){
        //        [self.navController setNavigationBarHidden:YES animated:animated];
        [self.navController setNavigationBarHidden:YES animated:animated];
    }else{
        //不在本页时，显示真正的nav bar
        //        [self.navController setNavigationBarHidden:NO animated:animated];
        [self.navController setNavigationBarHidden:NO animated:animated];
        //当不显示本页时，要么就push到下一页，要么就被pop了，那么就将delegate设置为nil，防止出现BAD ACCESS
        //之前将这段代码放在viewDidDisappear和dealloc中，这两种情况可能已经被pop了，self.navigationController为nil，这里采用手动持有navigationController的引用来解决
        if(self.navController.delegate == self){
            //如果delegate是自己才设置为nil，因为viewWillAppear调用的比此方法较早，其他controller如果设置了delegate就可能会被误伤
            self.navController.delegate = nil;
        }
    }
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    //实现滑动返回功能
    if (viewController == self.navigationController.viewControllers[0]) {
        self.navigationController.interactivePopGestureRecognizer.delegate = self.popDelegate;
    }else {
        self.navigationController.interactivePopGestureRecognizer.delegate = nil;
    }
}

//override var preferredStatusBarStyle: UIStatusBarStyle {
//    return UIStatusBarStyle.lightContent
//}

- (UIStatusBarStyle)preferredStatusBarStyle{
    [super preferredStatusBarStyle];
    return UIStatusBarStyleLightContent;
}


@end












