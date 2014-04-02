//
//  Utilities.h
//  STEWApi
//
//  Created by TMS  on 8/13/13.
//  Copyright (c) 2013 TMA Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JTUtilities : NSObject

+ (NSError  *) parseErrorData:(NSDictionary*)parsedObjects;
+ (NSString *) documentsDirectory;
+ (NSString *) libraryDirectory;
+ (NSDate*) convertIntValueInStringToNSDate:(NSString*) dateInNumber;
+ (NSNumber*) convertNSDateToNSNumber:(NSDate*) date;
@end
