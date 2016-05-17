/**
    PPRiskComponent.h
    PayPal
    Created by Matt Giger on 5/24/12.
    Copyright (c) 2015 PayPal, Inc. All rights reserved.
*/

#import <Foundation/Foundation.h>
#define kPPRiskComponentVersion                @"3.5.4"

@class CLLocation;

@interface PPRiskComponent : NSObject

/**
 Enums of source apps.
 */
typedef enum {
    PPRiskSourceAppUnknown = 0,
    PPRiskSourceAppPayPal = 10,
    PPRiskSourceAppEbay = 11,
    PPRiskSourceAppMSDK = 12
} PPRiskSourceApp;

/**
 Keys for use in addtionalParams of the initialization method.
 */
extern NSString *const kRiskManagerConfUrl;
extern NSString *const kRiskManagerNotifToken;
extern NSString *const kRiskManagerPairingId;
extern NSString *const kRiskManagerAdId;
extern NSString *const kRiskManagerNetworkAdapter;
extern NSString *const kRiskManagerIsStartAsyncService;
extern NSString *const kRiskManagerIsDisableRemoteConfig;

/**
 the linkerID
 */
@property (nonatomic, strong)    NSString*                linkerID;

/**
 the network infra
 */
@property (nonatomic, strong) void (^networkAdapterBlock)(NSMutableURLRequest *request, void (^completionBlock)(NSHTTPURLResponse *response, NSData *));

#pragma mark - INITIALIZATION METHODS

/**
 This initilization method is deprecated. 
 Please use the new initilization method.
 */
+ (PPRiskComponent*)initWithAppGuid:(NSString*)appGuid withAPNSToken:(NSString*)aPNSToken
               withConfigurationURL:(NSString*)confURL
                      withSourceApp:(PPRiskSourceApp)sourceApp
               withSourceAppVersion:(NSString *)sourceAppVersion
          withStartAsyncServiceFlag:(BOOL)isStartAsyncService
                      withPairingId:(NSString *)pairingId
                  withAdId:(NSString *)adId __deprecated;

/**
 This initilization method is deprecated.
 Please use the new initilization method.
 */
+ (PPRiskComponent*)initWithAppGuid:(NSString*)appGuid withAPNSToken:(NSString*)aPNSToken
               withConfigurationURL:(NSString*)confURL
                      withSourceApp:(PPRiskSourceApp)sourceApp
               withSourceAppVersion:(NSString *)sourceAppVersion
          withStartAsyncServiceFlag:(BOOL)isStartAsyncService
                      withPairingId:(NSString *)pairingId
                           withAdId:(NSString *)adId
         withNetworkAdapterBlock:(void (^)(NSMutableURLRequest *request, void (^completionBlock)(NSHTTPURLResponse *response, NSData *data)))networkBlock __deprecated;


/**
 Initialize the PPRiskComponent Library
 appGuid: source app's app guid
 sourceApp: source app enum, please refer to top of file
 sourceAppVersion: version of source app
 addtionalParams: addtional parameters in an NSDictionary
 */
+ (PPRiskComponent*)initWithAppGuid:(NSString*)appGuid
                      withSourceApp:(PPRiskSourceApp)sourceApp
               withSourceAppVersion:(NSString *)sourceAppVersion
               withAdditionalParams:(NSDictionary *)additionalParams;

/**
 Initialize the PPRiskComponent Library
 sourceApp: source app enum, please refer to top of file
 sourceAppVersion: version of source app
 addtionalParams: addtional parameters in an NSDictionary
 */
+ (PPRiskComponent*)initWithSourceApp:(PPRiskSourceApp)sourceApp
               withSourceAppVersion:(NSString *)sourceAppVersion
               withAdditionalParams:(NSDictionary *)additionalParams;

#pragma mark - PUBLIC METHODS AFTER INITIALIZATION

/**
 Returns the instance of the PPRiskComponent Library
 */
+ (PPRiskComponent*)sharedComponent;

/**
 Returns the PPRiskComponent payload as an NSDictionary
 */
- (NSDictionary*)dysonPayload;

/**
 Returns the PPRiskComponent payload as an NSString
 */
- (NSString*)riskPayload;

/**
 Sends an asynchornous PPRiskComponent payload
 */
- (void)sendImmediateUpdate;

/**
 *  startAsyncService
 *  sends a first update to the server immediately and then sets up a repeating timer to periodically
 *  update going forward.  Frequency is defined in configuration file.
 */
- (void)startAsyncService;

/**
 stops the async service
 */
- (void)stopAsyncService;

/**
 sets the location of PPRiskComponent
 */
- (void)setLocation:(CLLocation*)location;

/**
 returns the location of PPRiskComponent
 */
- (CLLocation *)getLocation;

/** get risk pairing id.
 */
- (NSString *)getPairingId;

/** remove risk pairing id.
 */
- (void)removePairingId;

/** generate a new risk pairing id. Also, an asynchronous PPRiskComponent payload will be sent.
 */
- (NSString*)generatePairingId:(NSString*)pairingId;

/** generate a new risk pairing id. Also, an asynchronous PPRiskComponent payload with additionalData will be sent.
    old additionalData will get purged everytime.
 */
- (NSString*)generatePairingId:(NSString*)pairingId withAdditionalData:(NSDictionary*)additionalData;

/** pass in additional data, any followed async/sync dyson payload will come with additional data.
 */
- (void)setAdditionalData:(id)data forKey:(NSString*)key;

#pragma mark - HELPERS

/** UUID of lenth 36
 */
+ (NSString*)uniqueID;

@end
