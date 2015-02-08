#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>
{
    NSArray* _matchEvents;
}

@property (nonatomic) UIWindow* window;
@property (nonatomic) UIFont* octiconsFont;

-(NSArray*)fetchGitHubSourceData;
-(NSArray*)fetchEvents:(NSString*)predicate;

@end

