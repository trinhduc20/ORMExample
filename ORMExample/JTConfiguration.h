//
// STEWConfiguration.h
//  STEWApi
//
//  Created by TMS  on 8/13/13.
//  Copyright (c) 2013 TMA Solutions. All rights reserved.
//

#ifndef NC_Configuration_h
#define NC_Configuration_h


#define STEWpaUSERNAME                        @"username"
#define STEWpaPASSWORD                        @"password"
#define STEWpaTOKENID                         @"token"
#define STEWpaMESSAGE                         @"message"
#define STEWpaAPPID                           @"appId"
#define STEWpaSTATUS                          @"status"
#define STEWpaTYPE                            @"type"
#define STEWpaUDID                            @"deviceUDID"
#define STEWpaDEVICETOKEN                     @"deviceToken"
#define STEWpaISPUSH                          @"isPush"
#define STEWpaTABLENAME                       @"tables"
#define STEWpaTABLENAMEONLY                   @"tableName"
#define STEWpaRESULT                          @"result"
#define STEWpaRESULTS                         @"results"
#define STEWpaLASTUPDATTE                     @"localLastUpdate"
#define STEWpaMAXRECORD                       @"maxRecord"
#define STEWpaPRIMARYKEY                      @"primaryKey"
#define STEWpaDELETEIDS                       @"deleteIds"
#define STEWpaREMAININGRECORD                 @"remainingRecord"
#define STEWpaRECORDS                         @"records"
#define STEWpaRECORD                          @"record"
#define STEWpaRESULTS                         @"results"
#define STEWpaTYPE                            @"type"
#define STEWpaNAME                            @"name"
#define STEWpaVALUE                           @"value"
#define STEWpaFIRST                           @"FIRST"
#define STEWpaOBJECTNAME                      @"objectName"
#define STEWpaOBJECTIDS                       @"objectIds"
#define STEWpaRECORDID                        @"recordId"
#define STEWpaPageIndex                       @"pageIndex"
#define STEWpaDATA                            @"data"


#define STEWpaDESCRIPTION                     @"description"

#define STEWpaUSERTOKEN                       @"userTokens"

#define STEWResponseOK                        @"OK"
#define STEWReponseError                      @"error"


#define kSTEWRequestErrorKey                  @"requestError"
#define kSTEWRequestResultKey                 @"requestResult"

#define kSTEWRequestContextInfoKey            @"requestContextInfo"
#define kSTEWRequestCompletedSelectorKey      @"requestselector"
#define kSTEWRequestSenderKey                 @"requesttarget"
#define kSTEWUserDataKey                      @"requestUserData"



#define kSTEWErrorDescriptionKey              @"NSLocalizedErrorDescriptionKey"

#define kSTEWErrorUserTokenKey                @"NSLocalizedErrorUserTokenKey"

#define kSTEWErrorDomainKey                   @"StewResponseError"
#define kSTEWInfoDomainKey                    @"StewResponseInfo"
#define kSTEWError                            111

#define kSTEWFirstTimeInstall                 @"FirstTimeInstall"

///Logging table
static NSString* const kSTEWTokenID             =   @"TokenID";
static NSString *const kSTEWUserToken           =   @"UserToken";
static NSString *const kSTEWMessage             =   @"Message";
static NSString *const kSTEWID                  =   @"ID";
static NSString *const kSTEWLOGGGING            =   @"Logging";
static NSString *const kSTEWDatabase            =   @"Stew.sqlite3";
static NSString *const kSTEWUserDevDatabase     =   @"Database.sql";
static NSString *const kSTEWLogLevel            =   @"LogLevel";



///Maximum logs stored in database
#define MESSAGE_MAX_NUMBER                      1000

#define UPDATED_OBJECT                          @"UpdateObject"
#define DELETED_OBJECT                          @"DeleteObject"
#define INSERTED_OBJECT                         @"InsertObject"

////Table columns
#define Column_UpdateTime                       @"UpdateTime"
#define Column_CreateTime                       @"CreateTime"
#define Column_ObjectId                         @"objectId"

#define PasswordEncryptDecrypt                  @"123456"

#ifdef DEBUG
#ifndef DLog
#   define DLog(fmt, ...) {NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);}
#endif
#ifndef ELog
#   define ELog(err) {if(err) DLog(@"%@", err)}
#endif
#else
#ifndef DLog
#   define DLog(...)
#endif
#ifndef ELog
#   define ELog(err)
#endif
#endif

#endif
