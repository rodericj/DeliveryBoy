//
//  DBViewController.m
//  Delivery Boy
//
//  Created by Roderic on 3/3/13.
//  Copyright (c) 2013 Roderic Campbell. All rights reserved.
//

#import "DBViewController.h"
#import "XMLReader.h"
#import "UtilitiesGeo.h"
///////////////////////////

@interface DestinationAnnotation : NSObject <MKAnnotation>
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@end

@implementation DestinationAnnotation
@synthesize coordinate;

@end


///////////////////////////


@interface DBViewController ()

@property (retain, nonatomic) MQRoute *route;
@property (retain, nonatomic) IBOutlet MKMapView *mapView;
@property (assign, nonatomic) CLLocationCoordinate2D destCoords;
@property (assign, nonatomic) NSUInteger currentTargetWaypoint;
@end

@implementation DBViewController

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


#pragma mark - View lifecycle
- (IBAction)tappedMap:(UIGestureRecognizer *)gestureRecognizer {
    
    // We don't care if it's the end of the gesture
    if ([gestureRecognizer state] != UIGestureRecognizerStateBegan) {
        return;
    }
    
    // clear all annotations first
    [self.mapView removeAnnotations:self.mapView.annotations];
    [self.mapView removeOverlays:self.mapView.overlays];
    
    //figure out the lat/long coords
    CGPoint destPoint = [gestureRecognizer locationInView:gestureRecognizer.view];
    self.destCoords = [[self mapView] convertPoint:destPoint toCoordinateFromView:[self mapView]];
    NSLog(@"User tapped on %f %f", self.destCoords.latitude, self.destCoords.longitude);
    
    // Create an annotation and put it on the map
    DestinationAnnotation *dest = [[DestinationAnnotation alloc] init];
    dest.coordinate = self.destCoords;
    [[self mapView] addAnnotation:dest];
    
    // From the user location, get the route to the destination
    CLLocationCoordinate2D userLocation = [[self mapView] userLocation].coordinate;
    [self.route getRouteWithStartCoordinate:userLocation endCoordinate:self.destCoords];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    //Setup the map view
    mqmapView = [[MQMapView alloc] initWithFrame:CGRectZero];
    
    self.route = [[MQRoute alloc] init];
    self.route.bestFitRoute = TRUE;
    self.route.mapView = mqmapView;
    self.route.delegate = self;
    self.route.routeType = MQRouteTypePedestrian;
    
}

- (void)zoomToAllRelevantInfo {
    MKMapPoint userPoint = MKMapPointForCoordinate(self.mapView.userLocation.location.coordinate);
    MKMapRect rect = MKMapRectMake(userPoint.x, userPoint.y, 1000, 1000);
    
    for(id<MKAnnotation> a in self.mapView.annotations) {
        MKMapPoint annotationPoint = MKMapPointForCoordinate(a.coordinate);
        MKMapRect annotationRect = MKMapRectMake(annotationPoint.x, userPoint.y, 0, 0);
        
        rect = MKMapRectUnion(annotationRect, rect);
    }
    
    [self.mapView setVisibleMapRect:rect
                        edgePadding:UIEdgeInsetsMake(100, 100, 100, 100)
                           animated:YES];

}

-(void)routeLoadFinished
{
    // get the raw xml passed back from the server:
    // NSLog(@"route is %@", self.route.rawXML);
    NSError *error = nil;
    NSDictionary *dictionary = [XMLReader dictionaryForXMLString:self.route.rawXML error:&error];
    if (error) {
        NSLog(@"error is %@", [error localizedDescription]);
    }
    NSArray *points = [[[[[dictionary objectForKey:@"response"] objectForKey:@"route"] objectForKey:@"shape"] objectForKey:@"shapePoints"] objectForKey:@"latLng"];
    
    CLLocationCoordinate2D coordinates[points.count];
    for (NSInteger index = 0; index < points.count; index++) {
        CLLocationCoordinate2D coord;
        coord.latitude = [[[points objectAtIndex:index] objectForKey:@"lat"] floatValue];
        coord.longitude = [[[points objectAtIndex:index] objectForKey:@"lng"] floatValue];
        NSLog(@"the next point is %@", [points objectAtIndex:index]);
        coordinates[index] = coord;
    }
    
    MKPolyline *polyLine = [MKPolyline polylineWithCoordinates:coordinates count:points.count];
    [self.mapView addOverlay:polyLine];
    
    // do something with all the maneuvers
    for ( MQManeuver *maneuver in self.route.maneuvers )
    {
        NSLog(@"%@", maneuver.narrative);
    }
}

- (void)viewDidUnload
{
    [self setMapView:nil];
    [super viewDidUnload];
}

-(MKAnnotationView*)mapView:(MKMapView *)aMapView viewForAnnotation:(id<MKAnnotation>)annotation {

    //Let the MapView create the view for the user location. Otherwise, it can be overridden to support custom user location views.
    if ([annotation isKindOfClass:[MKUserLocation class]])
        return nil;
    
    NSString *reuse = @"pin";
    [aMapView dequeueReusableAnnotationViewWithIdentifier:reuse];
    MKPinAnnotationView *pinView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:reuse];
    [pinView setAnnotation:annotation];
    pinView.animatesDrop = YES;
    pinView.pinColor = MKPinAnnotationColorGreen;
    return pinView;
}

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay {
    MKPolylineView *polylineView = [[MKPolylineView alloc] initWithPolyline:overlay];
    polylineView.strokeColor = [UIColor redColor];
    return polylineView;
}

- (void)mapViewWillStartLocatingUser:(MQMapView *)mapView {
    NSLog(@"MapDelegate notified of STARTING to track user");
}

- (void)mapViewDidStopLocatingUser:(MQMapView *)mapView {
    NSLog(@"MapDelegate notified of STOPPING tracking of user");
}

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {
    accuracyInMeters.text = [NSString stringWithFormat:@"%f m",userLocation.location.horizontalAccuracy];
    [self zoomToAllRelevantInfo];
    
    if ([self.mapView.annotations count] == 1) {
        return;
    }
    DestinationAnnotation *annotation = [self.mapView.annotations objectAtIndex:self.currentTargetWaypoint];
    // Determine if we are at the next point
    
    MKMapPoint point1 = MKMapPointForCoordinate(userLocation.coordinate);
    
    MKMapPoint point2 = MKMapPointForCoordinate(annotation.coordinate);
    
    CLLocationDistance distance = MKMetersBetweenMapPoints(point1,point2);
    
    if(distance < userLocation.location.horizontalAccuracy) {
        NSLog(@"Time to head to the next location");
        self.currentTargetWaypoint++;
    }

double heading = headingInDegrees(userLocation.location.coordinate.latitude, userLocation.location.coordinate.longitude,
                                  annotation.coordinate.latitude, annotation.coordinate.longitude);
NSLog(@"heading is %f distance is %f", heading, distance);

}

- (void)mapView:(MKMapView *)mapView didUpdateHeading:(CLHeading*)newHeading {
    NSLog(@"MapDelegate notified of new heading: %f OR %f", newHeading.trueHeading, newHeading.magneticHeading);
}

- (void)mapView:(MKMapView *)mapView didFailToLocateUserWithError:(NSError *)error {
    NSLog(@"MapDelegate notified of location tracking error %@", error);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}


@end
