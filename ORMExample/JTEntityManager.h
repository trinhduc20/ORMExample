//
//  NCEntityManager.h
//  Stew
//
//  Created by TMS  on 9/17/13.
//  Copyright (c) 2013 TMA Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol EntityDescriptor
+ (float) version;
+ (SEL) primaryKeyColumn;
@end

@interface JTEntityManager : NSObject{
    
}

@property (nonatomic, strong) NSMutableDictionary * structureMap;
@property (nonatomic, strong) NSString* databasePath;
@property (nonatomic, assign) BOOL isResetDatabase;

+ (JTEntityManager *)sharedInstance ;

- (void) generatePersistentStore:(Class)_class;
- (void) updateInstance:(id) instance;
- (void) removeInstance:(id) instance;
- (void) insertInstance:(id) instance;


typedef BOOL (^NCCondition)(id item);
- (NSArray*) fetch:(Class)_class;
- (NSArray*) fetch:(Class)_class where:(NCCondition)predicate;

@end
