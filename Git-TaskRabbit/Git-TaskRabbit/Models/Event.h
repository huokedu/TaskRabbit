//
//  Event.h
//  Git-TaskRabbit
//
//  Created by David Leistiko on 2/7/15.
//  Copyright (c) 2015 TaskRabbit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Event : NSManagedObject

@property (nonatomic, retain) NSString * avatarURL;
@property (nonatomic, retain) NSNumber * type;
@property (nonatomic, retain) NSString * repoName;
@property (nonatomic, retain) NSDate * timeStamp;
@property (nonatomic, retain) NSString * userName;
@property (nonatomic, retain) NSNumber * identifier;
@property (nonatomic, retain) NSMutableDictionary* repoDetails;

@end
