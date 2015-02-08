//
//  GitHubEventData.h
//  Git-TaskRabbit
//
//  Created by David Leistiko on 2/7/15.
//  Copyright (c) 2015 TaskRabbit. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum
{
    kGitHubType_WatchEvent,
    kGitHubType_ForkEvent,
    kGitHubType_UnknownEvent,
} GitHubType;

@interface GitHubEventData : NSObject

@property NSDictionary* primaryData;
@property NSDictionary* actorData;
@property NSDictionary* repoData;
@property NSMutableArray* watchers;
@property NSMutableArray* forks;

+(NSDate*)getDateForTimestamp:(NSString*)timestamp;
+(NSArray*)requestGitHubEventData;
+(NSString*)stringForGitHubType:(GitHubType)type;
+(GitHubType)gitHubTypeFromString:(NSString*)type;
+(NSString*)watchEventStr;
+(NSString*)forkEventStr;
+(NSString*)unknownEventStr;
-(void)requestFurtherDetails;

@end
