//
//  DBViewController.h
//  Delivery Boy
//
//  Created by Roderic on 3/3/13.
//  Copyright (c) 2013 Roderic Campbell. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <MQMapKit/MQMapKit.h>

@interface DBViewController : UIViewController <MQMapViewDelegate, MQRouteDelegate, MKMapViewDelegate> {
    MQMapView *mqmapView;
    IBOutlet UILabel *accuracyInMeters;
}
@end
