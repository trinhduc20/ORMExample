//
//  NCEntityManager.m
//  Stew
//
//  Created by TMS  on 9/17/13.
//  Copyright (c) 2013 TMA Solutions. All rights reserved.
//

#import "JTEntityManager.h"
#include "objc/runtime.h"
#import "JTConfiguration.h"
#import "FMDatabase.h"
#import "JTUtilities.h"

static NSMutableDictionary * databaseTypeMap = nil;
static const char * getPropertyType(objc_property_t property) {
    
    const char *attributes = property_getAttributes(property);
    char buffer[1 + strlen(attributes)];
    strcpy(buffer, attributes);
    char *state = buffer, *attribute;
    const char* type;
    while ((attribute = strsep(&state, ",")) != NULL) {
        
        if (attribute[0] == 'T' && attribute[1] != '@') {
            // it's a C primitive type:
            /*
             if you want a list of what will be returned for these primitives, search online for
             "objective-c" "Property Attribute Description Examples"
             apple docs list plenty of examples of what you get for int "i", long "l", unsigned "I", struct, etc.
             https://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
             */
            // it's another ObjC object type:
            //            NSString *name = [[NSString alloc] initWithBytes:attribute + 1 length:strlen(attribute) - 1 encoding:NSASCIIStringEncoding];
            //            type = (const char *)[name cStringUsingEncoding:NSASCIIStringEncoding];
            if (attribute[1] == 'i') {
                return "int";
            } else if (attribute[1] == 'd') {
                return "double";
            } else if(attribute[1] == 'f') {
                return "float";
            } else if (attribute[1] == 'l') {
                return "long";
            } else if (attribute[1] == 'c'){
                return "char";
            } else if (attribute[1] == 's'){
                return "short";
            } else if (attribute[1] == 'I'){
                return "unsigned";
            }
            return "NSInteger";
        }
        else if (attribute[0] == 'T' && attribute[1] == '@' && strlen(attribute) == 2) {
            // it's an ObjC id type:
            return "id";
        }
        else if (attribute[0] == 'T' && attribute[1] == '@') {
            // it's another ObjC object type:
            NSString *name = [[NSString alloc] initWithBytes:attribute + 3 length:strlen(attribute) - 4 encoding:NSASCIIStringEncoding];
            type = (const char *)[name cStringUsingEncoding:NSASCIIStringEncoding];
            return type;
        }
    }
    return "";
}

@interface ClassMap : NSObject

+ (id) mapForClass:(Class)_class;

- (void) fillColumns:(Class)_class;
- (void) buildQueries;

- (id) getValueForColumn:(NSString *)_column fromInstance:(id)instance;
- (id) getInstanceFromResultSet:(FMResultSet *)_rs formatDate:(BOOL) isFormat;
- (id) getValueForPrimaryKeyWithInstance:(id)instance;

- (NSArray *) getValuesForEntity:(id)instance;
- (NSArray *) getValuesToInsertForEntity:(id)instance;

@property (nonatomic, retain) Class class;
@property (nonatomic, retain) NSString * tableName;
@property (nonatomic, retain) NSNumber * version;
@property (nonatomic, retain) NSString * primaryKey;
@property (nonatomic, retain) NSArray * compositeKeyColumns;
@property (nonatomic, retain) NSArray * transientColumns;
@property (nonatomic, retain) NSDictionary * columns;
@property (nonatomic, retain) NSMutableDictionary * columnValues;
@property (nonatomic, retain) NSString * createQuery;
@property (nonatomic, retain) NSString * insertQuery;
@property (nonatomic, retain) NSString * selectQueryPrefix;
@property (nonatomic, retain) NSString * selectQuery;
@property (nonatomic, retain) NSString * replaceQuery;
@property (nonatomic, retain) NSString * updateQuery;
@property (nonatomic, retain) NSString * deleteQuery;
@property (nonatomic, retain) NSString * deleteAllQuery;
@property (nonatomic, retain) NSString * deleteBulkQueryFmtStr;
@property (nonatomic, retain) NSString * countQuery;

@property (nonatomic, retain) NSMutableArray* updatedObject;
@property (nonatomic, retain) NSMutableArray* deletedObject;
@property (nonatomic, retain) NSMutableArray* insertedObject;

///Using for auto increase of primary key
@property (nonatomic) NSInteger autoIncreasementIndex;

@end

@implementation ClassMap

@synthesize class,
            tableName,
            primaryKey,
            compositeKeyColumns,
            version,
            transientColumns,
            columns,
            columnValues,
            createQuery,
            insertQuery,
            replaceQuery,
            updateQuery,
            deleteQuery,
            deleteBulkQueryFmtStr,
            selectQuery,
            selectQueryPrefix,
            countQuery,
            updatedObject,
            insertedObject,
            deletedObject,autoIncreasementIndex;

+ (void) initialize {
    
	databaseTypeMap = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                       @"varchar", @"NSMutableString",
                       @"varchar", @"NSString",
                       @"integer", @"NSInteger",
                       @"integer", @"NSNumber",
                       @"integer", @"NSDate",
                       @"blob", @"NSDictionary",
                       @"blob", @"NSMutableDictionary",
                       @"blob", @"NSArray",
                       @"blob", @"NSMutableArray",
                       @"blob", @"NSData",
                       nil
                       ];
}

+ (id) mapForClass:(Class)_class {
    
	ClassMap * map = [[ClassMap alloc] init];
	[map fillColumns:_class];
	map.class = _class;
	map.version = [NSNumber numberWithInt:[_class version]];
	map.tableName = NSStringFromClass(_class);
    
    NSUserDefaults *prefs =[NSUserDefaults standardUserDefaults];
    NSDictionary* dicUpdate = [prefs objectForKey:UPDATED_OBJECT];
    map.updatedObject = [dicUpdate valueForKey:map.tableName];
    if(map.updatedObject == nil)
        map.updatedObject = [NSMutableArray array];
    
    NSDictionary* dicInsert = [prefs objectForKey:INSERTED_OBJECT];
    map.insertedObject = [dicInsert valueForKey:map.tableName];
    if(map.insertedObject == nil)
        map.insertedObject = [NSMutableArray array];
   
    NSDictionary* dicDelete = [prefs objectForKey:DELETED_OBJECT];
    map.deletedObject = [dicDelete valueForKey:map.tableName];
    if(map.deletedObject == nil)
        map.deletedObject = [NSMutableArray array];
    
    //All of model is have same name of primary key
    map.primaryKey = Column_ObjectId;
    
    //////init value for primary key
    map.autoIncreasementIndex = 0;
    
	[map buildQueries];
	
	return map;
}

- (void) fillColumns:(Class)_class {
    
	unsigned int outCount, i;
	objc_property_t *properties = class_copyPropertyList(_class, &outCount);
	NSMutableDictionary * dict = [NSMutableDictionary dictionaryWithCapacity:outCount];
    
	for (i = 0; i < outCount; i++) {
		objc_property_t property = properties[i];
		const char * name = property_getName(property);
		const char * type = getPropertyType(property);
		NSString * propName = [NSString stringWithUTF8String:name];
		NSString * propType = [NSString stringWithUTF8String:type];
		
		[dict setObject:propType forKey:propName];
	}
    [dict setObject:@"NSNumber" forKey:Column_UpdateTime];
    [dict setObject:@"NSNumber" forKey:Column_CreateTime];
	free(properties);
	self.columns = dict;
    
}
- (void) buildQueries {
    
	NSMutableArray * createParamsArray = [NSMutableArray arrayWithCapacity:[self.columns count]];
	NSMutableArray * updateParamsArray = [NSMutableArray arrayWithCapacity:[self.columns count]];
	NSMutableArray * insertParamsArray = [NSMutableArray arrayWithCapacity:[self.columns count]];
	
	for (NSString * col in [self.columns keyEnumerator]) {
		NSString * fieldDef = [NSString stringWithFormat:@"%@ %@", col, [databaseTypeMap objectForKey:[self.columns objectForKey:col]]];
		NSString * setPart = [NSString stringWithFormat:@"%@ = ?", col];
		
		[updateParamsArray addObject:setPart];
		[createParamsArray addObject:fieldDef];
		[insertParamsArray addObject:@"?"];
	}
	NSString * columnsStr = [[[self.columns keyEnumerator] allObjects] componentsJoinedByString:@", "];
	NSString * createParams = [createParamsArray componentsJoinedByString:@", "];
	NSString * insertParams = [insertParamsArray componentsJoinedByString:@", "];
	NSString * updateParams = [updateParamsArray componentsJoinedByString:@", "];
    NSString * createPrimaryKey = [NSString stringWithFormat:@" PRIMARY KEY (%@)", self.primaryKey];
	self.createQuery = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@, %@)", self.tableName, createParams, createPrimaryKey];
	self.insertQuery = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", self.tableName, columnsStr, insertParams];
	self.replaceQuery = [NSString stringWithFormat:@"REPLACE INTO %@ (%@) VALUES (%@)", self.tableName, columnsStr, insertParams];
	self.updateQuery = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@ = ?", self.tableName, updateParams, self.primaryKey];
	self.deleteQuery = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = ?", self.tableName, self.primaryKey];
	self.deleteBulkQueryFmtStr = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ IN (%%@)", self.tableName, self.primaryKey];
    self.countQuery = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@", self.tableName];
	self.selectQueryPrefix = [NSString stringWithFormat:@"SELECT %@ FROM %@", columnsStr, self.tableName];
	self.selectQuery = [NSString stringWithFormat:@"%@ WHERE %@ = ?", self.selectQueryPrefix, self.primaryKey];
}

- (id) getValueForColumn:(NSString *)_column fromInstance:(id)instance{
    
    id value = nil;
    value = [instance valueForKey:_column];
    
	if ([@"blob" isEqualToString:[databaseTypeMap objectForKey:[self.columns objectForKey:_column]]]) {
		NSString * error = nil;
		value = [NSPropertyListSerialization dataFromPropertyList:value format:NSPropertyListBinaryFormat_v1_0 errorDescription:&error];
	}else if([value isKindOfClass:[NSNumber class]]){
        if (strcmp([value objCType], @encode(BOOL)) == 0) {
            value =[NSNumber numberWithInt:[value integerValue]];
        } // QQQ Is this return correct value?
    }
    if(value == nil)
        value = [NSNull null];
	return value;
}


- (id) getInstanceFromResultSet:(FMResultSet *)_rs formatDate:(BOOL) isFormat{
	id instance = [[self.class alloc] init];
    
	int columnCount = [_rs columnCount];
	for (int columnIndex = 0; columnIndex < columnCount; columnIndex++) {
        NSString *column = [_rs columnNameForIndex:columnIndex];
        NSString *dataType = [self.columns objectForKey:column];
		id result = [_rs objectForColumnIndex:columnIndex];
		if (result != nil) {
			if ([result isKindOfClass:[NSData class]]) {
				NSString * error = nil;
				NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
				result = [NSPropertyListSerialization propertyListFromData:result
														  mutabilityOption:NSPropertyListMutableContainers
																	format:&format
														  errorDescription:&error];
                
			} else if ([dataType isEqualToString:@"NSDate"]) {
                if(isFormat == NO)
                    result = [JTUtilities convertIntValueInStringToNSDate:column];
                else
                    result = [_rs dateForColumn:column];
			} else if ([dataType isEqualToString:@"int"]) {
                result = [NSNumber numberWithInt:[_rs intForColumn:column]];
            } else if ([dataType isEqualToString:@"float"]) {
                result = [NSNumber numberWithFloat:[[_rs stringForColumn:column] floatValue]];
            } else if ([dataType isEqualToString:@"short"]) {
                result = [NSNumber numberWithInt:[_rs intForColumn:column]];
            } else if ([dataType isEqualToString:@"double"]) {
                result = [NSNumber numberWithDouble:[[_rs stringForColumn:column] doubleValue]];
            }else if ([dataType isEqualToString:@"unsigned"]) {
                result = [NSNumber numberWithInt:[_rs intForColumn:column]];
            }else if ([dataType isEqualToString:@"long"]) {
                result = [NSNumber numberWithLong:[_rs longForColumn:column]];
            } else if ([dataType isEqualToString:@"char"]) {
                result = [NSNumber numberWithChar:(char)[_rs intForColumn:column]];
            }
		}
        [instance setValue:result forKey:column];
	}
	return instance;
}


- (id) getValueForPrimaryKeyWithInstance:(id)instance {
	return [self getValueForColumn:self.primaryKey fromInstance:instance];
}

- (NSArray *) getValuesToInsertForEntity:(id)instance
{
	NSMutableArray * values = [NSMutableArray array];
	for (NSString * column in [self.columns keyEnumerator]) {
        id object = [self getValueForColumn:column fromInstance:instance];
        [values addObject:object];
	}
	return values;
}
- (NSArray*) getValuesForEntity:(id) instance{
    
    NSMutableArray * values = [NSMutableArray array];
    
    for (NSString * column in [self.columns keyEnumerator]) {
        if([column isEqualToString:Column_UpdateTime]){
            NSNumber* value = [JTUtilities convertNSDateToNSNumber:[NSDate date]];
            [values addObject:[NSString stringWithFormat:@"%lld",[value longLongValue]]];
        }else{
            id value = [self getValueForColumn:column fromInstance:instance];
            [values addObject: value];
        }
    }
    id value = [self getValueForColumn:Column_ObjectId fromInstance:instance];
    [values addObject: value];
    
    return values;
    
}
@end

@interface JTEntityManager(){
    FMDatabase* db;
}
@property (nonatomic, strong)  FMDatabase* db;

@end

@implementation JTEntityManager

@synthesize db = _db;
@synthesize isResetDatabase = _isResetDatabase;

@synthesize databasePath = _databasePath;

+ (JTEntityManager *)sharedInstance {
    
    static dispatch_once_t pred = 0;
    static JTEntityManager *sharedInstance = nil;
    dispatch_once(&pred, ^{
        sharedInstance = [[self alloc] init]; // or some other init method
    });
    
    return sharedInstance;
    
}

- (id) init{
    
    self = [super init];
    
    if(self){
        _isResetDatabase = NO;
        _structureMap = [NSMutableDictionary dictionary];
        [self createDatabaseName:kSTEWUserDevDatabase path:[JTUtilities documentsDirectory]];
        _databasePath     = [[JTUtilities documentsDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"/STEW/%@",kSTEWUserDevDatabase]];
        _db = [FMDatabase databaseWithPath:_databasePath];
        [_db open];
    }
    return self;
    
}


- (BOOL) createDatabaseName:(NSString*) name path:(NSString*) path{
    
    NSString* sqliteFile = nil;
    NSError* error = nil;
    
    NSFileManager* fm = [NSFileManager defaultManager];
    NSString* stewFolder = [path stringByAppendingPathComponent:@"/STEW"];
    
    if (![fm fileExistsAtPath:stewFolder])
        [fm createDirectoryAtPath:stewFolder withIntermediateDirectories:NO attributes:nil error:&error]; //Create folder
    if(error == nil){
        sqliteFile = [stewFolder stringByAppendingPathComponent:name];
        if (![fm fileExistsAtPath:sqliteFile]){
            return YES;
        }else
            return NO;
    }else{
        NSLog( @"STEW Error is:  can not create database");
        return NO;
    }
    return NO;
    
}

- (NSArray*) generateSchemaJSON{
    
    NSMutableArray* tables = [NSMutableArray array];
    [[_structureMap allKeys] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSMutableDictionary* dic = [NSMutableDictionary dictionary];
        NSMutableArray* array = [NSMutableArray array];
        ClassMap* class = (ClassMap*)[_structureMap valueForKey:(NSString*) obj];
        if(![class.tableName isEqualToString:kSTEWLOGGGING]){
            [[class.columns allKeys] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSMutableDictionary* myDic = [NSMutableDictionary dictionary];
                [myDic setValue:[databaseTypeMap objectForKey:[class.columns objectForKey:obj]] forKey:@"type"];
                [myDic setValue:(NSString*)obj forKey:@"colName"];
                [array addObject:myDic];
            }];
            [dic setValue:(NSString*) obj forKey:@"name"];
            [dic setValue:array forKey:@"columns"];
            [dic setValue:class.primaryKey forKey:@"primary_key"];
            [tables addObject:dic];
        }
    }];
    return tables;
}

- (void) removeWithClass:(Class)_class andPrimaryKey:(id)key {
	ClassMap * classMap = [_structureMap objectForKey:NSStringFromClass(_class)];
	
	[self.db executeUpdate:classMap.deleteQuery, key];
}

- (void) removeWithClass:(Class)_class andPrimaryKeyList:(NSArray *)keys {
	ClassMap * classMap = [_structureMap objectForKey:NSStringFromClass(_class)];
	
	NSMutableArray * partsArray = [NSMutableArray arrayWithCapacity:[keys count]];
	for (int i = 0; i < [keys count]; i++) {
		[partsArray addObject:@"?"];
	}
    
	NSString * queryStr = [NSString stringWithFormat:classMap.deleteBulkQueryFmtStr, [partsArray componentsJoinedByString:@","]];
	
	[self.db executeUpdate:queryStr withArgumentsInArray:keys];
}

- (void) removeWithClass:(Class)_class andQuery:(id)query, ... {
	ClassMap * classMap = [_structureMap objectForKey:NSStringFromClass(_class)];
    NSString * queryStr = nil;
    if(query == nil)
        queryStr = [NSString stringWithFormat:@"DELETE FROM %@", classMap.tableName];
	else
        queryStr = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@", classMap.tableName, query];
    va_list args;
    va_start(args, query);
    
	[self.db executeUpdate:queryStr withArgumentsInArray:nil];
	
	va_end(args);
}

- (id) loadSingleWithClass:(Class)_class andQuery:(id)query, ... {
	ClassMap * classMap = [_structureMap objectForKey:NSStringFromClass(_class)];
	
	NSString * queryStr = [NSString stringWithFormat:@"%@ %@", classMap.selectQueryPrefix, query];
    
    va_list args;
    va_start(args, query);
	
	FMResultSet * rs = [self.db executeQuery:queryStr withArgumentsInArray:nil];
	
	va_end(args);
    
	id instance = nil;
	
	if ([rs next]) {
		instance = [classMap getInstanceFromResultSet:rs formatDate:YES];
	}
	
	[rs close];
	
	return instance;
}

- (NSArray *) loadArrayWithClass:(Class)_class andQuery:(NSString *)query, ... {
    
	ClassMap * classMap = [_structureMap objectForKey:NSStringFromClass(_class)];
    NSString*  queryStr = nil;
    if(query != nil){
        queryStr = [NSString stringWithFormat:@"%@ WHERE %@", classMap.selectQueryPrefix, query];
    }else
        queryStr = [NSString stringWithFormat:@"%@", classMap.selectQueryPrefix];

	va_list args;
    va_start(args, query);
	
	FMResultSet * rs = [self.db executeQuery:queryStr withArgumentsInArray:nil];
    
	va_end(args);
	
	NSMutableArray * resultSet = [NSMutableArray array];
	while ([rs next]) {
		[resultSet addObject:[classMap getInstanceFromResultSet:rs formatDate:YES]];
	}
	
	[rs close];
	
	return resultSet;
}

- (id) loadWithClass:(Class)_class andPrimaryKey:(id)key formatDate:(BOOL) isFormat{
	ClassMap * classMap = [_structureMap objectForKey:NSStringFromClass(_class)];
	
	FMResultSet * rs = [self.db executeQuery:classMap.selectQuery, key];
	
	id instance = nil;
	
	if ([rs next]) {
		instance = [classMap getInstanceFromResultSet:rs formatDate:isFormat];
	}
	[rs close];
	
	return instance;
}

- (BOOL)hasEntityForClass:(Class)_class andQuery:(NSString *)query, ... {
	ClassMap * classMap = [_structureMap objectForKey:NSStringFromClass(_class)];

	NSString * queryStr = [NSString stringWithFormat:@"SELECT 1 FROM %@ WHERE %@", classMap.tableName, query];
	
	va_list args;
    va_start(args, query);
	
	FMResultSet * rs = [self.db executeQuery:queryStr withArgumentsInArray:nil];
	
	va_end(args);
	
	BOOL hasRows = [rs next];
	
	[rs close];
	
	return hasRows;
}

#pragma mark 
#pragma For developer use

- (void) generatePersistentStore:(Class)_class {
 
    [_structureMap setObject:[ClassMap mapForClass:_class] forKey:NSStringFromClass(_class)];
    ClassMap * classMap = [_structureMap objectForKey:NSStringFromClass(_class)];
    [_db executeUpdate:classMap.createQuery];
    
    
}
- (NSArray*) getValuesForEntity:(id) instance classMap:(ClassMap*) map{
    
    NSMutableArray * values = [NSMutableArray array];
    
    for (NSString * column in [map.columns keyEnumerator]) {
        if([column isEqualToString:Column_CreateTime]){
            NSString* value = [self getValueOfInstance:instance atColumn:column];
            [values addObject:value];
        }else if([column isEqualToString:Column_UpdateTime]){
            NSNumber* value = [NSNumber numberWithLongLong:[@(floor([[NSDate  date] timeIntervalSince1970] * 1000)) longLongValue]];
            [values addObject:[NSString stringWithFormat:@"%lld",[value longLongValue]]];
        }else{
            [values addObject: [map getValueForColumn:column fromInstance:instance]];
        }
    }
    [values addObject:[map getValueForColumn:Column_ObjectId fromInstance:instance]];

    return values;
    
}

- (void) updateInstance:(id)instance{
    ClassMap * classMap = [_structureMap objectForKey:NSStringFromClass([instance class])];
    if(classMap){
        
        NSArray* values = [self getValuesForEntity:instance classMap:classMap];
        if([_db executeUpdate:classMap.updateQuery withArgumentsInArray:values] == YES){
            id obj = values[0];
            if(obj != [NSNull null]){
                [classMap.updatedObject addObject:obj];
                
                NSMutableDictionary* dicUpdate = [[[NSUserDefaults standardUserDefaults]  objectForKey:UPDATED_OBJECT] mutableCopy];
                if(dicUpdate == nil){
                    dicUpdate = [NSMutableDictionary dictionary];
                }
                [dicUpdate setValue:classMap.updatedObject forKey:classMap.tableName];
                [[NSUserDefaults standardUserDefaults] setObject:dicUpdate forKey:UPDATED_OBJECT];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }

        }
    }
}

- (void) removeInstance:(id)instance{
    ClassMap * classMap = [_structureMap objectForKey:NSStringFromClass([instance class])];
    if(classMap){
        id obj = [classMap getValueForPrimaryKeyWithInstance:instance];
        [classMap.columnValues removeObjectForKey:obj];
        if([_db executeUpdate:classMap.deleteQuery, obj] == YES){
            if(obj != [NSNull null]){
                [classMap.deletedObject addObject:obj];
                NSMutableDictionary* dicDelete = [[[NSUserDefaults standardUserDefaults]  objectForKey:DELETED_OBJECT] mutableCopy];
                if(dicDelete == nil){
                    dicDelete = [NSMutableDictionary dictionary];
                }
                [dicDelete setValue:classMap.deletedObject forKey:classMap.tableName];
                [[NSUserDefaults standardUserDefaults] setObject:dicDelete forKey:DELETED_OBJECT];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }
    }
}

- (void) insertInstance:(id)instance{
    
    ClassMap * classMap = [_structureMap objectForKey:NSStringFromClass([instance class])];
    if(classMap){
        NSArray* values = [classMap getValuesToInsertForEntity:instance];
        if([_db executeUpdate:classMap.insertQuery withArgumentsInArray:values] == YES){
            id obj = values[0];
            if(obj != [NSNull null]){
                
                //Increate auto index for primary key
                classMap.autoIncreasementIndex ++;
                
                [classMap.insertedObject addObject:obj];
                NSMutableDictionary* dicInsert = [[[NSUserDefaults standardUserDefaults]  objectForKey:INSERTED_OBJECT] mutableCopy];
                if(dicInsert == nil){
                    dicInsert = [NSMutableDictionary dictionary];
                }
                [dicInsert setValue:classMap.insertedObject forKey:classMap.tableName];
                [[NSUserDefaults standardUserDefaults] setObject:dicInsert forKey:INSERTED_OBJECT];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                }
            
        }
    }
}

- (NSArray*) fetch:(Class)_class{
    
    return [self loadArrayWithClass:_class andQuery:nil];
    
}

- (NSArray*) fetch:(Class)_class where:(NCCondition)predicate{
    NSArray* array = [self fetch:_class];
    NSMutableArray* result = [NSMutableArray array];
    for(id item in array){
        if(predicate(item)){
            [result addObject:item];
        }
    }
    return result;
}
- (id) getValueOfInstance:(id)instance atColumn:(NSString *)column{
    
    ClassMap * classMap = [_structureMap objectForKey:NSStringFromClass([instance class])];
    NSString* primaryKey = classMap.primaryKey;
    NSString* value =  [classMap getValueForColumn:primaryKey fromInstance:instance];
    
    FMResultSet *result = [self.db executeQuery:[NSString stringWithFormat: @"SELECT %@ FROM %@ WHERE %@ = '%@'",column,classMap.tableName,primaryKey, value]];
    
    while ([result next]) {
        NSDictionary* dic = [result resultDictionary];
        id value = [dic objectForKey:column];
        return value;
    }
    return nil;
 
}

@end