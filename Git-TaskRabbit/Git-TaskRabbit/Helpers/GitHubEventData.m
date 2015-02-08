//
//  GitHubEventData.m
//  Git-TaskRabbit
//
//  Created by David Leistiko on 2/7/15.
//  Copyright (c) 2015 TaskRabbit. All rights reserved.
//

#import "GitHubEventData.h"

// the URL where we can retrieve the event data
NSString* const kGitHubSourceDataUrlStr = @"https://api.github.com/orgs/taskrabbit/events";
NSString* const kGitHUbRepoWatchersUrlStr = @"https://api.github.com/repos/%@/watchers?page=%d";
NSString* const kGitHubRepoForksUrlStr = @"https://api.github.com/repos/%@/forks?page=%d";
NSString* const kWatchEventStr = @"WatchEvent";
NSString* const kForkEventStr = @"ForkEvent";
NSString* const kUnknownEventStr = @"UnknownEvent";

// Private implementation
@interface GitHubEventData()
-(void)getActions:(GitHubType)type;
@end

@implementation GitHubEventData

// returns the watch event str
+(NSString*)watchEventStr
{
    return kWatchEventStr;
}

// returns the fork event str
+(NSString*)forkEventStr
{
    return kForkEventStr;
}

// return the unknown event str
+(NSString*)unknownEventStr
{
    return kUnknownEventStr;
}

// Gets a formatted NSDate from the timestamp value
+(NSDate*)getDateForTimestamp:(NSString*)timestamp
{
    // Build the date
    NSString* year = [timestamp substringWithRange:NSMakeRange(0, 4)];
    NSString* month = [timestamp substringWithRange:NSMakeRange(5, 2)];
    NSString* day = [timestamp substringWithRange:NSMakeRange(8, 2)];
    NSString* months[12] = {
        @"Jan", @"Feb", @"Mar", @"Apr",
        @"May", @"Jun", @"Jul", @"Aug",
        @"Sep", @"Oct", @"Nov", @"Dec"};
    int index = [month intValue];
    NSString* dateStr = [NSString stringWithFormat:@"%@ %@, %@", months[index - 1], day, year];
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setTimeZone:[NSTimeZone localTimeZone]];
    [dateFormat setDateFormat:@"MMM dd, yyyy"];
    NSDate* date = [dateFormat dateFromString:dateStr];
    return date;
}

// returns a newly initialize git hub event data
+(NSArray*)requestGitHubEventData
{
    NSMutableArray* gitHubEventDataArray = nil;
    
    // perform the get request to read data from GitHub
    NSError* error = [[NSError alloc] init];
    NSString *urlString = kGitHubSourceDataUrlStr;
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    NSURLResponse* response = [[NSURLResponse alloc] init];
    NSData* data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response error:&error];
    
    // convert the data and return serialized json-data which translates to an
    // array of dictionaries
    NSArray* result = (NSArray*)[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    
    gitHubEventDataArray = [NSMutableArray arrayWithCapacity:[result count]];
    for (NSDictionary* source in result) {
        GitHubEventData* eventData = [[GitHubEventData alloc] init];
        eventData.primaryData = source;
        [gitHubEventDataArray addObject:eventData];
    }
    
    // return the retrieved data
    return gitHubEventDataArray;
}

// Returns the git-hub type based on the string value passed in
+(GitHubType)gitHubTypeFromString:(NSString*)type
{
    if ([type isEqualToString:kWatchEventStr]) {
        return kGitHubType_WatchEvent;
    }
    else if ([type isEqualToString:kForkEventStr]) {
        return kGitHubType_ForkEvent;
    }
    return kGitHubType_UnknownEvent;
}

// Returns the string representation for the github type
+(NSString*)stringForGitHubType:(GitHubType)type
{
    switch (type)
    {
        case kGitHubType_WatchEvent:    return kWatchEventStr;
        case kGitHubType_ForkEvent:     return kForkEventStr;
        case kGitHubType_UnknownEvent:  return kUnknownEventStr;
        default:                        return kUnknownEventStr;
    }
}

// Override init function to allocate properties
-(id)init
{
    if (self = [super init]) {
        self.watchers = [NSMutableArray array];
        self.forks = [NSMutableArray array];
    }
    return self;
}

// further populates the github event data by making other URL requests
// for actor information, repo information and other relevant items
-(void)requestFurtherDetails
{
    // request "actor" details
    NSString* urlString = [[self.primaryData objectForKey:@"actor"] objectForKey:@"url"];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    NSURLResponse* response = [[NSURLResponse alloc] init];
    NSData* data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response error:NULL];
    id converted = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    self.actorData = (NSDictionary*)converted;
    
    // request "repo" details
    urlString = [[self.primaryData objectForKey:@"repo"] objectForKey:@"url"];
    request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    response = [[NSURLResponse alloc] init];
    data = [NSURLConnection sendSynchronousRequest:request
                                 returningResponse:&response error:NULL];
    converted = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    self.repoData = (NSDictionary*)converted;
    
    // build the list of watchers/forks actions
    [self getActions:kGitHubType_WatchEvent];
    [self getActions:kGitHubType_ForkEvent];
}

// Retrieves the list of all watchers and adds them to the array
-(void)getActions:(GitHubType)type
{
    // first determine which array we will be working with
    NSMutableArray* actionArray = nil;
    switch (type) {
        // Need to retrieve watch action items
        case kGitHubType_WatchEvent:
            actionArray = self.watchers;
            break;
        // Need to retrieve fork action items
        case kGitHubType_ForkEvent:
            actionArray = self.forks;
            break;
        // If we are not of the right type then we can skip all of this
        case kGitHubType_UnknownEvent:
        default:
            return;
    }

    // allocate the array to store the action details
    actionArray = [NSMutableArray array];
    NSString* baseUrl = [self.repoData objectForKey:@"url"];
    NSArray* workingArray = nil;
    NSUInteger curPage = 1;
    
    // Continue to loop until the response we get back is a nil/empty array
    while (TRUE) {
        
        // build the url
        NSString* urlString =
        [NSString stringWithFormat:@"%@/events?page=%lu", baseUrl, curPage];
        
        // perform the GET operation
        NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        NSURLResponse* response = [[NSURLResponse alloc] init];
        NSData* data = [NSURLConnection sendSynchronousRequest:request
                                     returningResponse:&response error:NULL];
        id converted = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        workingArray = (NSArray*)converted;
        
        // if we got no data back, then we can break from this loop
        // as we know that we have retrieved all relevant data
        if (workingArray == nil || [workingArray count] == 0) {
            break;
        }
        
        // Iterate over each of the elements in the array and create a user
        // dictionary that will contain relevant values relating to the user
        // who performed the action on the repo.  This data end up as part
        // of the 'Event' model
        for (NSDictionary* dict in workingArray) {
            
            // Make sure that the event type for the repo matches
            // the type we passed in to this function so that we know
            // we are storing the correct event info.
            NSString* event = dict[@"type"];
            GitHubType eventType = [GitHubEventData gitHubTypeFromString:event];
            if (eventType != type) {
                continue;
            }
            
            // Grab the values that we care about
            NSDictionary* actor = dict[@"actor"];
            NSString* actorUrl = actor[@"url"];
            NSString* avatarUrl = actor[@"avatar_url"];
            NSDate* date = [GitHubEventData getDateForTimestamp:dict[@"created_at"]];
            
            // lookup the username
            NSString* urlString = actorUrl;
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
            NSURLResponse* response = [[NSURLResponse alloc] init];
            NSData* data = [NSURLConnection sendSynchronousRequest:request
                                                 returningResponse:&response error:NULL];
            id converted = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            NSDictionary* userDetails = (NSDictionary*)converted;
            NSString* username = userDetails[@"name"];
            
            // build the dictionary that stores the data we just pulled which will
            // get tossed into the database as part of the model that represents
            // this current object.
            NSMutableDictionary* userDict = [NSMutableDictionary dictionaryWithCapacity:3];
            [userDict setValue:username forKey:@"username"];
            [userDict setValue:avatarUrl forKey:@"avatarUrl"];
            [userDict setValue:date forKey:@"date"];

            // insert into action array
            [actionArray addObject:userDict];
        }
        
        // increment to get the next data
        ++curPage;
    }
}

@end
