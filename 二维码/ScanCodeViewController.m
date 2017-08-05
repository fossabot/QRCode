//
//  ScanCodeViewController.m
//  二维码
//
//  Created by LeoLi on 2017/4/26.
//  Copyright © 2017年 WisageTech. All rights reserved.
//

#import "ScanCodeViewController.h"

#define TINTCOLOR_ALPHA 0.7  //浅色透明度

@interface ScanCodeViewController ()<AVCaptureMetadataOutputObjectsDelegate>
@property (nonatomic, strong) AVCaptureSession *session; //输入输出的中间桥梁
@property (nonatomic,strong) UIView * scanView;
@property (nonatomic, strong) UIView *scanCropView;  //扫描区域的view
@property (nonatomic) BOOL isFlashLightOn;
@property (nonatomic,strong) UIButton * flashButton;
@property (nonatomic,strong) NSTimer * timer;
@property (nonatomic) CGFloat scanCropViewTop;
@property (nonatomic) CGFloat ScanCropViewHeight;
@property (nonatomic, assign) BOOL isOpenLight;  //是否打开闪光灯
@end

@implementation ScanCodeViewController

#pragma mark - Lazy Loading

#pragma mark - Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupUI];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.isFlashLightOn = NO;
    [self.flashButton setHidden:NO];
    self.title = @"二维码扫描";
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.timer invalidate];
    [self.session stopRunning];;
    [self.flashButton setHidden:YES];
}

- (void)dealloc
{
    [_flashButton removeFromSuperview];
    
    [self setFlashButton:nil];
}

//创建闪光灯按钮
- (UIButton *)flashButton
{
    if (!_flashButton)
    {
        _flashButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _flashButton.frame = CGRectMake(self.view.frame.size.width - 40, 25, 30, 30);
       
        _flashButton.backgroundColor=[UIColor clearColor];
        [_flashButton setBackgroundImage:[UIImage imageNamed:@"Light_on"] forState:UIControlStateNormal];
        [_flashButton setBackgroundImage:[UIImage imageNamed:@"Light_off"] forState:UIControlStateSelected];
        [_flashButton addTarget:self action:@selector(flashButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        [self.navigationController.view addSubview:_flashButton];
    }
    return _flashButton;
}

-(void)flashButtonClick:(UIButton *)button
{
    if (self.isFlashLightOn)
    {

        self.isOpenLight = NO;
        self.isFlashLightOn = NO;
        button.selected = NO;
    }
    else
    {

        self.isOpenLight = YES;
        self.isFlashLightOn = YES;
        button.selected = YES;
    }
}
- (void)openLight:(BOOL)isOpen
{
    
}

#pragma mark - UI
- (void)setupUI
{
    //重新定义扫描界面
    [self setOverLayPickerView];
    
    //关闭闪光灯

    self.isOpenLight = NO;
    [self.view addSubview:self.scanView];
    [self scanBeginning];
}

-(void)setIsOpenLight:(BOOL)isOpenLight
{
    _isOpenLight = isOpenLight;
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    if (isOpenLight) { //打开闪光灯
        if ([device hasFlash]) {
            BOOL locked = [device lockForConfiguration:&error];
            if (locked) {
                device.torchMode = AVCaptureTorchModeOn;
                [device unlockForConfiguration];
            }
        }
    }else {// 关闭闪光灯
        if ([device hasFlash]) {
            [device lockForConfiguration:nil];
            [device setTorchMode: AVCaptureTorchModeOff];
            [device unlockForConfiguration];
        }
    }
}

#pragma mark - 重新定义扫描界面
- (void)setOverLayPickerView
{
    CGFloat SCANCROPVIEW_WIDE_HEIGHT = self.view.frame.size.width * 0.75;
    CGFloat SCANVIEW_EDGE_BOTTOM = (self.view.frame.size.height - SCANCROPVIEW_WIDE_HEIGHT)/2;
    CGFloat SCANVIEW_EDGE_TOP = SCANVIEW_EDGE_BOTTOM;
    CGFloat SCANVIEW_EDGE_LEFT_RIGHT = (self.view.frame.size.width - SCANCROPVIEW_WIDE_HEIGHT)/2;
    
    self.scanCropViewTop = SCANVIEW_EDGE_TOP;
    self.ScanCropViewHeight = SCANCROPVIEW_WIDE_HEIGHT;
    
    //扫描界面
    self.scanView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width,self.view.frame.size.height-64)];
    self.scanView.backgroundColor = [UIColor clearColor];
    //    [self.view addSubview:self.scanView];
    
    //最上部的View
    UIView * upView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width,SCANVIEW_EDGE_TOP)];
    upView.alpha = TINTCOLOR_ALPHA;
    upView.backgroundColor = [UIColor cyanColor];
    [self.scanView addSubview:upView];
    
    //左侧的view
    UIView *leftView = [[UIView alloc] initWithFrame:CGRectMake(0, SCANVIEW_EDGE_TOP, SCANVIEW_EDGE_LEFT_RIGHT,SCANCROPVIEW_WIDE_HEIGHT)];
    leftView.alpha = TINTCOLOR_ALPHA;
    leftView.backgroundColor = [UIColor cyanColor];
    [self.scanView addSubview:leftView];
    
    /******************中间扫描区域****************************/
    _scanCropView = [[UIView alloc] initWithFrame:CGRectMake(SCANVIEW_EDGE_LEFT_RIGHT , SCANVIEW_EDGE_TOP, SCANCROPVIEW_WIDE_HEIGHT , SCANCROPVIEW_WIDE_HEIGHT)];
    //scanCropView.image=[UIImage imageNamed:@""];
    
    //    scanCropView.layer.borderColor = [UIColor whiteColor].CGColor;
    _scanCropView.layer.borderWidth = 1.0;
    _scanCropView.layer.borderColor = [UIColor grayColor].CGColor;
    
    _scanCropView.backgroundColor = [UIColor clearColor];
    [self.scanView addSubview:_scanCropView];
    
    //画扫描区域的四个角
    UIGraphicsBeginImageContext(_scanCropView.bounds.size);
    
    UIBezierPath * path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(20, 1)];
    [path addLineToPoint:CGPointMake(1, 1)];
    [path addLineToPoint:CGPointMake(1, 20)];
    [[UIColor redColor] setStroke];
    path.lineWidth = 8.0;
    [path stroke];
    
    UIBezierPath * path1 = [UIBezierPath bezierPath];
    [path1 moveToPoint:CGPointMake(1, _scanCropView.frame.size.height - 20)];
    [path1 addLineToPoint:CGPointMake(1, _scanCropView.frame.size.height - 1)];
    [path1 addLineToPoint:CGPointMake(20, _scanCropView.frame.size.height - 1)];
    [[UIColor redColor] setStroke];
    path1.lineWidth = 8.0;
    [path1 stroke];
    
    UIBezierPath * path2 = [UIBezierPath bezierPath];
    [path2 moveToPoint:CGPointMake(_scanCropView.frame.size.width - 20, _scanCropView.frame.size.height - 1)];
    [path2 addLineToPoint:CGPointMake(_scanCropView.frame.size.width - 1, _scanCropView.frame.size.height - 1)];
    [path2 addLineToPoint:CGPointMake(_scanCropView.frame.size.width - 1, _scanCropView.frame.size.height - 20)];
    [[UIColor redColor] setStroke];
    path2.lineWidth = 8.0;
    [path2 stroke];
    
    UIBezierPath * path3 = [UIBezierPath bezierPath];
    [path3 moveToPoint:CGPointMake(_scanCropView.frame.size.width - 20, 1)];
    [path3 addLineToPoint:CGPointMake(_scanCropView.frame.size.width - 1, 1)];
    [path3 addLineToPoint:CGPointMake(_scanCropView.frame.size.width - 1, 20)];
    [[UIColor redColor] setStroke];
    path3.lineWidth = 8.0;
    [path3 stroke];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    UIImageView *imgView = [[UIImageView alloc] initWithImage:img];
    [_scanCropView addSubview:imgView];
    
    
    //右侧的view
    UIView *rightView = [[UIView alloc] initWithFrame:CGRectMake(SCANVIEW_EDGE_LEFT_RIGHT + SCANCROPVIEW_WIDE_HEIGHT, SCANVIEW_EDGE_TOP, SCANVIEW_EDGE_LEFT_RIGHT,SCANCROPVIEW_WIDE_HEIGHT)];
    rightView.alpha = TINTCOLOR_ALPHA;
    rightView.backgroundColor = [UIColor cyanColor];
    [self.scanView addSubview:rightView];
    
    //底部view
    UIView *downView = [[UIView alloc] initWithFrame:CGRectMake(0, SCANVIEW_EDGE_TOP + SCANCROPVIEW_WIDE_HEIGHT, self.view.frame.size.width, SCANVIEW_EDGE_BOTTOM)];
    downView.alpha = TINTCOLOR_ALPHA;
    downView.backgroundColor = [UIColor cyanColor];
    [self.scanView addSubview:downView];
    
    
    //画中间的基准线
    UIView* line = [[UIView alloc] initWithFrame:CGRectMake(SCANVIEW_EDGE_LEFT_RIGHT + 5, SCANVIEW_EDGE_TOP, SCANCROPVIEW_WIDE_HEIGHT - 10, 2)];
    line.backgroundColor = [UIColor cyanColor];
    [self.scanView addSubview:line];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:.008 target:self selector:@selector(animate:) userInfo:line repeats:YES];
    
    //用于说明的label
    UILabel * labIntroudction= [[UILabel alloc] init];
    labIntroudction.backgroundColor = [UIColor clearColor];
    labIntroudction.frame=CGRectMake(0, 12, self.view.frame.size.width, 50);
    CGPoint center = labIntroudction.center;
    center.x = self.view.center.x;
    labIntroudction.center = center;
    [labIntroudction setTextAlignment:NSTextAlignmentCenter];
    //    labIntroudction.numberOfLines=2;
    labIntroudction.textColor = [UIColor redColor];
    labIntroudction.text=@"将二维码放入框内，即可自动扫描";
    [downView addSubview:labIntroudction];
}

-(void)animate:(NSTimer * )timer
{
    UIView * line = (UIView *)[timer userInfo];
    if (line.frame.origin.y == self.ScanCropViewHeight + self.scanCropViewTop - 2)
    {
        [line setHidden:YES];
        CGRect frame = line.frame;
        CGPoint point = frame.origin;
        point.y = self.scanCropViewTop;
        frame.origin = point;
        line.frame = frame;
    }
    else
    {
        [line setHidden:NO];
        CGRect frame = line.frame;
        CGPoint point = frame.origin;
        point.y ++;
        frame.origin = point;
        line.frame = frame;
    }
}


- (void)scanBeginning
{
    //获取摄像设备
    AVCaptureDevice * device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //创建输入流
    AVCaptureDeviceInput * input = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    //创建输出流
    AVCaptureMetadataOutput * output = [[AVCaptureMetadataOutput alloc]init];
    //设置代理 在主线程里刷新
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    //初始化链接对象
    self.session = [[AVCaptureSession alloc]init];
    //高质量采集率
    [self.session setSessionPreset:AVCaptureSessionPresetHigh];
    
    [self.session addInput:input];
    [self.session addOutput:output];
    //设置扫码支持的编码格式(如下设置条形码和二维码兼容)
    output.metadataObjectTypes=@[AVMetadataObjectTypeQRCode,AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code];
    
    AVCaptureVideoPreviewLayer * layer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    layer.videoGravity=AVLayerVideoGravityResizeAspectFill;
    layer.frame=self.view.layer.bounds;
    [self.view.layer insertSublayer:layer atIndex:0];
    
    //rectOfInterest 是一个 CGRect 类型, 其值在(0,1)之间
    CGFloat x = _scanCropView.frame.origin.x / CGRectGetWidth(self.view.frame);
    CGFloat y = _scanCropView.frame.origin.y / CGRectGetWidth(self.view.frame);
    CGFloat width = _scanCropView.frame.size.width / CGRectGetHeight(self.view.frame);
    CGFloat height = _scanCropView.frame.size.height / CGRectGetHeight(self.view.frame);
    output.rectOfInterest = CGRectMake(x, y, width, height);
    NSLog(@"______%@",NSStringFromCGRect(CGRectMake(x, y, width, height)));
    
    //开始捕获
    [self.session startRunning];
}


#pragma mark - Delegate
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    if (metadataObjects.count>0) {
        [self.session stopRunning];
        [self.timer invalidate];
        AVMetadataMachineReadableCodeObject * metadataObject = metadataObjects.firstObject;
        //输出扫描字符串
        NSString *resultStr = metadataObject.stringValue;
        NSLog(@"resultStr______________%@",resultStr);
        //扫描成功后一般做保存数据, 跳转等操作
    }
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end
