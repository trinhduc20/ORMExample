//
//  Utilities.m
//  STEWApi
//
//  Created by TMS  on 8/13/13.
//  Copyright (c) 2013 TMA Solutions. All rights reserved.
//

#import "JTUtilities.h"
#import "JTConfiguration.h"
#import <CommonCrypto/CommonDigest.h>

@implementation JTUtilities

+(NSError*)parseErrorData:(NSDictionary*)parsedObjects
{
    NSError *responseError = nil;
    if([[parsedObjects objectForKey:STEWpaSTATUS] isEqualToString:STEWReponseError])
    {
        NSInteger domainCode = kSTEWError;
        NSString *domain = kSTEWErrorDomainKey;
        
        NSMutableDictionary *errorInfo = [NSMutableDictionary dictionary];
        
        NSString *errDescription = [parsedObjects objectForKey:STEWpaDESCRIPTION];
        [errorInfo setObject:[NSString stringWithFormat:@"%@", errDescription] forKey:kSTEWErrorDescriptionKey];
        NSString *errToken = [parsedObjects objectForKey:STEWpaUSERTOKEN];
        
        [errorInfo setObject:[NSString stringWithFormat:@"%@", errToken] forKey:STEWpaUSERTOKEN];
        
        responseError = [ [NSError alloc] initWithDomain:domain code:domainCode userInfo:errorInfo];
    }
    return responseError;
}

+ (NSString *)documentsDirectory
{
	NSString *documentsDirectory= nil;
	if(! documentsDirectory) {
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		documentsDirectory = [paths objectAtIndex:0];
	}
	return documentsDirectory;
}
+ (NSString *) libraryDirectory{
    
    NSString *librarysDirectory= nil;
	if(! librarysDirectory) {
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
		librarysDirectory = [paths objectAtIndex:0];
	}
	return librarysDirectory;
}

// NSDate should be converted into unixtime without milliseconds.
+ (NSNumber*) convertNSDateToNSNumber:(NSDate*) date{
    return [NSNumber numberWithInteger:[[NSNumber numberWithDouble: [date timeIntervalSince1970]] integerValue]];
}
// It expects integer value of unixtime in NSString.
+ (NSDate*) convertIntValueInStringToNSDate:(NSString*) dateInNumber {
    return [NSDate dateWithTimeIntervalSince1970:[dateInNumber doubleValue]];;
}

@end
