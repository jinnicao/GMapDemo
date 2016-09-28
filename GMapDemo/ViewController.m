//
//  ViewController.m
//  GMapDemo
//
//  Created by xiaolong on 9/21/16.
//  Copyright © 2016 xiaolong. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property(nonatomic, strong) GMapDemo *gmapDemo;
@property(nonatomic, strong) CADisplayLink *display;

- (void)step;

@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}


- (void)loadView {
	self.gmapDemo = [[GMapDemo alloc] init];
	self.view = [self.gmapDemo loadGMap];
	
	self.display = [CADisplayLink displayLinkWithTarget:self selector:@selector(step)];
	[self.display addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)step {
	if(self.gmapDemo != nil) {
		[self.gmapDemo step];
	}
}


@end
