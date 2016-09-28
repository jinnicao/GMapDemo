//
//  GMapDemo.m
//  GMapDemo
//
//  Created by xiaolong on 9/21/16.
//  Copyright © 2016 xiaolong. All rights reserved.
//


@import CoreLocation;
@import GoogleMaps;
@import GooglePlaces;

//#import <GoogleMaps/GoogleMaps.h>
//#import <GooglePlaces/GooglePlaces.h>

#import "GMapDemo.h"

#define IS_OS_8_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
#define kApiKey @"AIzaSyB6elu33RgTFTyBmKGdgWQWsnfqVrMnQ34"

@interface GMapDemo () <CLLocationManagerDelegate, GMSMapViewDelegate>

@property CLLocationCoordinate2D position;
@property GMSMarker *curPosMarker;
@property(nonatomic, strong) GMSMapView *mapView;
@property(nonatomic, strong) CLLocationManager *locationMgr;
@property(nonatomic, strong) NSArray *locations;

- (void)updatePostion;
- (void)markCurrentPosition;
- (void)initMapElements;
- (void)addOverlay:(NSDictionary *)info;
- (void)drawPath:(NSArray *)wayPoints;
- (void)sendHttpRequest:(NSString *)url queries:(NSDictionary *)qs responseHandler:(void(^)(NSDictionary *json, NSError *err))h;

@end

@implementation GMapDemo

//@synthesize position;
//@synthesize mapView;
//@synthesize locationMgr;

//public methods region

- (instancetype)init {
	[GMSServices provideAPIKey:kApiKey];
	[GMSPlacesClient provideAPIKey:kApiKey];

	return self;
}

- (UIView*)loadGMap {
	self.locationMgr = [[CLLocationManager alloc] init];
	self.locationMgr.delegate = self;
	self.locationMgr.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
	self.locationMgr.distanceFilter = 50;
#ifdef __IPHONE_8_0
	if(IS_OS_8_OR_LATER) {
		// Use one or the other, not both. Depending on what you put in info.plist
		[self.locationMgr requestWhenInUseAuthorization];
		//[self.locationMgr requestLocation];
		NSLog(@"request location service");
	}
#endif
	[self.locationMgr startUpdatingLocation];
	//self.locationMgr = locMgr;
	NSLog(@"setup location manager");

	GMSCameraPosition *camera = [GMSCameraPosition cameraWithLatitude:self.position.latitude
															longitude:self.position.longitude
																 zoom:16];
	GMSMapView *view = [GMSMapView mapWithFrame:CGRectZero camera:camera];
	view.delegate = self;
	view.myLocationEnabled = YES;
	view.mapType = kGMSTypeSatellite;
	//view.mapType = kGMSTypeTerrain;
	
	NSBundle *mainBundle = [NSBundle mainBundle];
	NSURL *styleUrl = [mainBundle URLForResource:@"gmapstyle_test" withExtension:@"json"];
	NSError *error;
	// Set the map style by passing the URL for style.json.
	GMSMapStyle *style = [GMSMapStyle styleWithContentsOfFileURL:styleUrl error:&error];
	if (!style) {
		NSLog(@"The style definition could not be loaded: %@", error);
	}
	view.mapStyle = style;
	
	NSLog(@"load gmap at position: %f, %f", self.position.latitude, self.position.longitude);
	self.mapView = view;
	return self.mapView;
}

- (void)step {
	//NSLog(@"step gmap view");
	static int count = 0;
	if(self.curPosMarker != nil) {
		self.curPosMarker.icon = [UIImage imageNamed:[NSString stringWithFormat:@"%d", count % 3]];
		count++;
		CGPoint p = [self.mapView.projection pointForCoordinate:self.position];
		//NSLog(@"zoom:%f, cur pos:%f|%f", self.mapView.camera.zoom, p.x, p.y);
	}
}

//delegate methods region

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
	CLLocation *loc = [locations lastObject];
	CLLocationCoordinate2D coord = loc.coordinate;
	//self.position = coord;
	self.position = CLLocationCoordinate2DMake(37.757605,-122.507277);
	
	NSLog(@"update position to %f, %f", self.position.latitude, self.position.longitude);
	
	[self updatePostion];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	NSLog(@"please enable location service to continue: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
	switch (status) {
		case kCLAuthorizationStatusAuthorizedAlways:
		case kCLAuthorizationStatusAuthorizedWhenInUse:
			[self.locationMgr startUpdatingLocation];
			NSLog(@"start update location");
			break;
		case kCLAuthorizationStatusDenied:
			NSLog(@"user denied to access location service");
			break;
		case kCLAuthorizationStatusRestricted:
			NSLog(@"this app is not allowed to access location service");
		default:
			break;
	}
}

- (void)mapView:(GMSMapView *)mapView didTapOverlay:(nonnull GMSOverlay *)overlay {
	if([overlay.title  isEqual: @"CurrentPostion"]) {
		//return true;
		return;
	}
	
	GMSGroundOverlay *lay = (GMSGroundOverlay *)overlay;
	
	CLLocationCoordinate2D dst = lay.position;
	CLLocationCoordinate2D src = self.position;
	NSMutableDictionary *qs = [[NSMutableDictionary alloc] init];
	qs[@"key"] = kApiKey;
	qs[@"mode"] = @"walking";
	qs[@"origin"] = [NSString stringWithFormat:@"%f,%f", src.latitude, src.longitude];
	qs[@"destination"] = [NSString stringWithFormat:@"%f,%f", dst.latitude, dst.longitude];
	NSLog(@"marker clicked:%@", overlay.title);
	[self sendHttpRequest:@"https://maps.googleapis.com/maps/api/directions/json"
				  queries:qs
		  responseHandler:^(NSDictionary *json, NSError *err) {
			  if(err) {
				  NSLog(@"find path err:%@", err);
				  return;
			  }
			  if(![json[@"status"]  isEqual: @"OK"]) {
				  NSLog(@"find path err status:%@", json[@"status"]);
				  return;
			  }
			  NSDictionary *route = json[@"routes"][0];
			  if(!route) {
				  NSLog(@"no routes found");
				  return;
			  }
			  NSDictionary *leg = route[@"legs"][0];
			  if(!leg) {
				  NSLog(@"no leg found");
				  return;
			  }
			  NSMutableArray *wps = [[NSMutableArray alloc] init];
			  [wps addObject:@{@"lat":[NSNumber numberWithDouble:self.position.latitude],
							   @"lng":[NSNumber numberWithDouble:self.position.longitude]}];
			  for(NSDictionary *step in leg[@"steps"]) {
				  [wps addObject:step[@"start_location"]];
				  //[wps addObject:step[@"end_location"]];
			  }

			  [wps addObject:@{@"lat":[NSNumber numberWithDouble:lay.position.latitude],
							   @"lng":[NSNumber numberWithDouble:lay.position.longitude]}];
			  NSLog(@"way points:%@", wps);
			  
			  [self drawPath:wps];
			  
		  }];
	//return true;
	return;
}

//private methods region

- (void)updatePostion {
	if(!self.mapView) {
		return;
	}
	
	NSLog(@"move camera to position: %f, %f", self.position.latitude, self.position.longitude);
	[self.mapView animateToCameraPosition:[GMSCameraPosition cameraWithTarget:self.position zoom:16]];
	//[self.locationMgr stopUpdatingLocation];
	[self markCurrentPosition];
	[self initMapElements];
}

- (void)markCurrentPosition {
	GMSMarker *marker = [[GMSMarker alloc] init];
	marker.position = self.position;
	marker.title = @"CurrentPosition";
	marker.map = self.mapView;
	self.curPosMarker = marker;
}

- (void)initMapElements {
	NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
	dic[@"key"] = kApiKey;
	dic[@"location"] = [NSString stringWithFormat:@"%f,%f", self.position.latitude, self.position.longitude];
	//dic[@"radius"] = @"2000";//meters
	dic[@"type"] = @"lodging";
	dic[@"rankby"] = @"distance";
	[self sendHttpRequest:@"https://maps.googleapis.com/maps/api/place/nearbysearch/json"
				  queries:dic
		  responseHandler:^(NSDictionary *json, NSError *err) {
			  if(err) {
				  NSLog(@"get nearby places failed:%@", err);
				  return;
			  }
			  if(![json[@"status"]  isEqual: @"OK"]) {
				  NSLog(@"get nearby places err status:%@", json[@"status"]);
				  return;
			  }
			  for(NSDictionary *rst in json[@"results"]) {
				  [self addOverlay:rst];
			  }
		  }];
}

- (void)addOverlay:(NSDictionary *)info {
	NSNumber *lat = info[@"geometry"][@"location"][@"lat"];
	NSNumber *lng = info[@"geometry"][@"location"][@"lng"];
	CLLocationCoordinate2D position = CLLocationCoordinate2DMake([lat doubleValue],[lng doubleValue]);
	NSString *title = info[@"name"];
	UIImage *icon = [UIImage imageNamed:@"skull"];
	GMSGroundOverlay *lay = [GMSGroundOverlay groundOverlayWithPosition:position
																   icon:icon
															  zoomLevel:18];
	lay.title = title;
	lay.tappable = true;
	lay.map = self.mapView;
	NSLog(@"new location:%@,%f,%f", lay.title, position.latitude, position.longitude);
}

- (void)drawPath:(NSArray *)wayPoints {
	GMSMutablePath *path = [[GMSMutablePath alloc] init];
	for(NSDictionary *wp in wayPoints) {
		[path addCoordinate:CLLocationCoordinate2DMake([wp[@"lat"] doubleValue], [wp[@"lng"] doubleValue])];
	}
	GMSPolyline *line = [GMSPolyline polylineWithPath:path];
	line.strokeWidth = 4;
	line.map = self.mapView;
	
	GMSMarker *marker = [[GMSMarker alloc] init];
	NSDictionary *wp = [wayPoints lastObject];
	marker.position = CLLocationCoordinate2DMake([wp[@"lat"] doubleValue],[wp[@"lng"] doubleValue]);
	//marker.title = info[@"name"];
	marker.icon = [UIImage imageNamed:@"battle"];
	marker.map = self.mapView;
}

- (void)sendHttpRequest:(NSString*)url queries:(NSDictionary *)qs responseHandler:(void(^)(NSDictionary *json, NSError *err))h {
	NSString *params = @"";
	if(qs) {
		params = @"?";
		for(NSString *key in [qs allKeys]) {
			params = [params stringByAppendingString:[NSString stringWithFormat:@"%@=%@&", key, qs[key]]];
		}
		params = [params stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"&"]];
	}
	
	NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
	NSURLSession *ssn = [NSURLSession sessionWithConfiguration:conf];
	url = [url stringByAppendingString:[params stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
	NSURL *addr = [NSURL URLWithString:url];
	NSLog(@"http request start:%@, %@", url, addr);
	NSURLSessionTask *task = [ssn dataTaskWithURL:addr completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if(error) {
			NSLog(@"http request err:%@", error);
			return h(nil, error);
		}
		
		NSHTTPURLResponse *hr = (NSHTTPURLResponse*)response;
		if(hr.statusCode != 200) {
			NSLog(@"http response err:%d", (int)hr.statusCode);
			return h(nil, [NSError errorWithDomain:@"http status err" code:hr.statusCode userInfo:nil]);
		}
		
		NSError *jserr;
		NSDictionary *jd = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jserr];
		if(jserr) {
			NSLog(@"parse json data err:%@", jserr);
			return h(nil, jserr);
		}
		
		NSLog(@"response data successfully:%@", jd);
		h(jd, nil);
	}];
	[task resume];
}

@end

