//
//  ViewController.m
//  Dyson
//
//  Created by Bondi, Andrea on 17/05/2016.
//  Copyright © 2016 Bondi, Andrea. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"
#import "PPRiskComponent.h"
#import <CoreLocation/CoreLocation.h>
#import <AFNetworking/AFNetworking.h>
#import <SVProgressHUD/SVProgressHUD.h>

#define SERVICE_NAME @"DYSON_TEST_APP"

@import CoreLocation;
@import SafariServices;

@interface ViewController () <CLLocationManagerDelegate, SFSafariViewControllerDelegate>
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (weak, nonatomic) IBOutlet UIView *completePaymentView;
@property (weak, nonatomic) IBOutlet UIButton *startCheckoutButton;
@property (weak, nonatomic) IBOutlet UITextField *tokenTextField;
@property (weak, nonatomic) IBOutlet UITextField *payerIDTextField;
@property PPRiskComponent *component;
@property NSString *ecToken;
@property NSString *payerID;
@property SFSafariViewController *safariView;
@property AFHTTPSessionManager *httpSessionManager;
@end

@implementation ViewController

NSString *const kPayPalNvpEndpoint = @"http://www.andreabondi.it/onetouchserver/process.php";
NSString *const kPayPalRedirectUrl = @"https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=%@";

// Dyson constants
NSString *kSourceAppVersion;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [SVProgressHUD setDefaultStyle: SVProgressHUDStyleDark];
    
    self.ecToken = nil;
    
    self.httpSessionManager = [AFHTTPSessionManager manager];
    self.httpSessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];
    self.httpSessionManager.requestSerializer = [AFHTTPRequestSerializer serializer];
    
    // Get app version
    kSourceAppVersion = [NSString stringWithFormat:@"Version %@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    
    // Hide the "Complete payment" view until we don't have a token from the Server and payment is authorised by payer
    [_completePaymentView setHidden:YES];
    
    // Uncomment to activate debug mode for Dyson
    // NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    // [defaults setBool:YES forKey:@"dyson.debug.mode"];
    
    ///////////////////////////////////////////////
    // Configure Observers after redirect from SafariViewController
    ///////////////////////////////////////////////

    [[NSNotificationCenter defaultCenter]
     addObserver: self selector: @selector(completePayPalCheckout:) name: @"completePayPalCheckout" object: nil];
    
    [[NSNotificationCenter defaultCenter]
     addObserver: self selector: @selector(cancelPayPalCheckout) name: @"cancelPayPalCheckout" object: nil];
    
    ///////////////////////////////////////////////
    // Start location services so that Dyson can get location data
    ///////////////////////////////////////////////
    
    _locationManager = [[CLLocationManager alloc] init];
    [_locationManager setDelegate: self];
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [_locationManager requestAlwaysAuthorization];
    [_locationManager startUpdatingLocation];
}

- (IBAction)checkoutButton_pressed:(id)sender {
    [self prepareForCheckout];
}

- (IBAction)completePaymentButton_pressed:(UIButton *)sender {
    [self completeCheckout];
}

- (void)prepareForCheckout{
    [SVProgressHUD showWithStatus: @"Starting PayPal Checkout"];
    
    // Call the SetEC to get a token, then open the SVC
    [self setEC];
}

///////////////////////////////////////////////
// This method sends the Risk Payload and loads the SafariViewController.
// Called inside the setEc method after receiving a token.
///////////////////////////////////////////////

- (void)startCheckoutwithToken:(NSString *)token {
    
    // Upload the Risk Payload using internal method
    
    NSString *pairingId = [self sendDysonPayloadWithPairingId: token];
    NSLog(@"Paring ID is %@", pairingId);
    
    [SVProgressHUD dismiss];
    
    NSURL *redirectUrl = [NSURL URLWithString:[NSString stringWithFormat: kPayPalRedirectUrl, token]];
    
    // Initialize the Safari View
    self.safariView = [[SFSafariViewController alloc] initWithURL: redirectUrl entersReaderIfAvailable: false];
    self.safariView.delegate = self;
    
    // Display the Safari View
    UIViewController *vc = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    [vc presentViewController: self.safariView animated: YES completion: nil];
}

- (void)completeCheckout{
    [SVProgressHUD showWithStatus: @"Completing PayPal Checkout"];
    
    [self doExpressCheckoutPaymentWithToken:self.ecToken andPayerId:self.payerID];
}

#pragma mark Risk payload upload

- (NSString *)sendDysonPayloadWithPairingId:(NSString *)pairingId {
    NSString *resultingPairingId = pairingId;
    
    if(nil == self.component) {
        NSDictionary *additionalParams = @{ kRiskManagerPairingId: pairingId };
        self.component = [PPRiskComponent initWithSourceApp: PPRiskSourceAppUnknown
                                       withSourceAppVersion: kSourceAppVersion
                                       withAdditionalParams: additionalParams];
    }
    else {
        resultingPairingId = [[PPRiskComponent sharedComponent] generatePairingId: pairingId];
    }
    
    return resultingPairingId;
}

#pragma mark Set and Do EC gateways to middleware server

- (void)setEC {
    
    // The middleware server with paypal=setEC parameter will return a JSON with a token.
    // The additional parameter platform=ios is needed to configure the correct Return and Cancel URLs
    NSDictionary *nvpParams = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"setEC", @"paypal",
                               @"ios",@"platform",
                               nil];
    
    [self.httpSessionManager GET: kPayPalNvpEndpoint parameters: nvpParams progress: nil success: ^(NSURLSessionTask *task, id responseObject) {
        //NSLog(@"SetEC URL%@", task.originalRequest.URL);
        NSString *responseString = [[NSString alloc] initWithData: responseObject encoding: NSUTF8StringEncoding];
        NSLog(@"Response: %@", responseString);
        
        NSError *errorJson;
        NSDictionary *aSetEcResponse = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableContainers|NSJSONReadingAllowFragments error:&errorJson];
        
        BOOL error = NO;
        self.ecToken = nil;
        
        if (![[aSetEcResponse valueForKey:@"ACK"] isEqualToString: @"Success" ]){
            error = YES;
        }
        
        if(!error) {
            self.ecToken = [aSetEcResponse valueForKey:@"TOKEN"];
            
            if(nil != self.ecToken) {
                NSLog(@"Got EC Token: %@", self.ecToken);
                
                // Send the risk payload and open the SVC
                [self startCheckoutwithToken: self.ecToken];
            }
        }
        else {
            [self showError];
        }
        
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        [self showError];
    }];
}

- (void)doExpressCheckoutPaymentWithToken:(NSString *)token andPayerId:(NSString *)payerId {

    // The middleware server with paypal=doEC parameter will return a JSON with PayPal response.
    // Token and PayerID parameters required. Can be retrieved from the Return URL (this case) or
    // GetExpressCheckoutDetails can be called with token.
    NSDictionary *nvpParams = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"doEC", @"paypal",
                               token,@"token",
                               payerId, @"PayerID",
                               nil];
    
    [self.httpSessionManager GET: kPayPalNvpEndpoint parameters: nvpParams progress: nil success: ^(NSURLSessionTask *task, id responseObject) {
        //NSLog(@"DoEC URL%@", task.originalRequest.URL);
        NSString *responseString = [[NSString alloc] initWithData: responseObject encoding: NSUTF8StringEncoding];
        NSLog(@"Response: %@", responseString);
        
        NSError *errorJson;
        NSDictionary *aSetEcResponse = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableContainers|NSJSONReadingAllowFragments error:&errorJson];
        
        BOOL error = NO;
        self.ecToken = nil;
        
        if (![[aSetEcResponse valueForKey:@"ACK"] isEqualToString: @"Success" ]){
            error = YES;
        }
        
        if(false == error) {
            [self showSuccess];
        }
        else {
            [self showError];
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        [self showError];
    }];
}

#pragma mark Display alerts

- (void)showError {
    [SVProgressHUD dismiss];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle: @"Something went wrong..."
                                                                   message: @":("
                                                            preferredStyle: UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle: @"OK"
                                                       style: UIAlertActionStyleDefault
                                                     handler: ^(UIAlertAction * action) {
                                                         [alert dismissViewControllerAnimated:YES completion:nil];
                                                     }];
    [alert addAction: okAction];
    [self presentViewController: alert animated: YES completion: nil];
}

- (void)showSuccess {
    [SVProgressHUD dismiss];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle: @"Payment Complete"
                                                                   message: @":)"
                                                            preferredStyle: UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle: @"OK"
                                                       style: UIAlertActionStyleDefault
                                                     handler: ^(UIAlertAction * action) {
                                                         [alert dismissViewControllerAnimated:YES completion:nil];
                                                     }];
    [alert addAction: okAction];
    [self presentViewController: alert animated: YES completion: nil];
}

#pragma mark Selectors for Notification

- (void)completePayPalCheckout:(NSNotification *)n {
    NSLog(@"completePayPalCheckout()");
    [self.safariView dismissViewControllerAnimated: true completion: nil];
    if(nil != self.ecToken) {
        [SVProgressHUD dismiss];
        
        self.ecToken = n.userInfo[@"token"];
        self.payerID = n.userInfo[@"PayerID"];

        [_startCheckoutButton setEnabled:NO];
        [_tokenTextField setText: self .ecToken];
        [_payerIDTextField setText:self.payerID];
        [_completePaymentView setHidden:NO];
    }
    else {
        [self showError];
    }
}

- (void)cancelPayPalCheckout {
    NSLog(@"cancelPayPalCheckout()");
    [self.safariView dismissViewControllerAnimated: true completion: nil];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle: @"Payment Cancelled from user"
                                                                   message: @":("
                                                            preferredStyle: UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle: @"OK"
                                                       style: UIAlertActionStyleDefault
                                                     handler: ^(UIAlertAction * action) {
                                                         [alert dismissViewControllerAnimated:YES completion:nil];
                                                     }];
    [alert addAction: okAction];
    [self presentViewController: alert animated: YES completion: nil];
}


#pragma mark SFSafariViewControllerDelegate Methods
- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    NSLog(@"safariViewControllerDidFinish");
    [controller dismissViewControllerAnimated: true completion: nil];
}

#pragma mark CLLocationManagerDelegate Methods
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(nonnull NSArray<CLLocation *> *)locations {
    // If it's a relatively recent event, turn off updates to save power.
    CLLocation *location = [locations lastObject];
    NSDate *eventDate = location.timestamp;
    NSTimeInterval howRecent = [eventDate timeIntervalSinceNow];
    if (fabs(howRecent) < 15.0) {
        /*
         // If the event is recent, do something with it.
         NSLog(@"latitude %+.6f, longitude %+.6f\n",
         location.coordinate.latitude,
         location.coordinate.longitude);
         */
    }
}

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"locationManager:didFailWithError %@", error.description);
}

@end
