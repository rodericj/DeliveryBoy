//
//  DBViewController.m
//  Delivery Boy
//
//  Created by Roderic on 3/3/13.
//  Copyright (c) 2013 Roderic Campbell. All rights reserved.
//

#import "DBViewController.h"
#import "XMLReader.h"

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
    CLLocationCoordinate2D destCoords = [[self mapView] convertPoint:destPoint toCoordinateFromView:[self mapView]];
    NSLog(@"User tapped on %f %f", destCoords.latitude, destCoords.longitude);
    
    // Create an annotation and put it on the map
    DestinationAnnotation *dest = [[DestinationAnnotation alloc] init];
    dest.coordinate = destCoords;
    [[self mapView] addAnnotation:dest];
    
    // From the user location, get the route to the destination
    CLLocationCoordinate2D userLocation = [[self mapView] userLocation].coordinate;
    [self.route getRouteWithStartCoordinate:userLocation endCoordinate:destCoords];
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
    NSLog(@"array of dots from xml is %@", points);
    
    
    CLLocationCoordinate2D user = self.mapView.userLocation.location.coordinate;
    MKMapRect unionRect = MKMapRectMake(user.latitude, user.longitude, 1, 1);
    CLLocationCoordinate2D coordinates[points.count];
    for (NSInteger index = 0; index < points.count; index++) {
        CLLocationCoordinate2D coord;
        coord.latitude = [[[points objectAtIndex:index] objectForKey:@"lat"] floatValue];
        coord.longitude = [[[points objectAtIndex:index] objectForKey:@"lng"] floatValue];
        coordinates[index] = coord;
        
        unionRect = MKMapRectUnion(MKMapRectMake(coord.latitude, coord.longitude, 1, 1), unionRect);
    }
    MKPolyline *polyLine = [MKPolyline polylineWithCoordinates:coordinates count:points.count];
    [self.mapView addOverlay:polyLine];
    // [self.mapView setVisibleMapRect:unionRect];
    
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

-(MKAnnotationView*)mapView:(MKMapView *)aMapView viewForAnnotation:(id<MQAnnotation>)annotation {
    
    MKAnnotationView *pinView = nil;
    
    //Let the MapView create the view for the user location. Otherwise, it can be overridden to support custom user location views.
    if ([annotation isKindOfClass:[MQUserLocation class]])
        return nil;
    
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
    
    self.mapView.region = MKCoordinateRegionMakeWithDistance(userLocation.coordinate, MAX(userLocation.location.horizontalAccuracy, 1000), MAX(userLocation.location.horizontalAccuracy, 1000));
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
