#import "AppDelegate.h"
#import "GitHubEventData.h"
#import "RepoDetailViewController.h"
#import "UserCollectionViewCell.h"

@implementation RepoDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UINib *nib = [UINib nibWithNibName:@"UserCollectionViewCell" bundle:nil];
    [self.collectionView registerNib:nib forCellWithReuseIdentifier:@"UserCollectionViewCell"];
    
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setTimeZone:[NSTimeZone localTimeZone]];
    [dateFormat setDateFormat:@"MMM dd, yyyy"];
    NSDate* date = [self.repoDetailsData objectForKey:@"repoDate"];
    
    // determine the action taken
    NSString* actionCountStr = nil;
    NSUInteger forkCount = [[self.repoDetailsData objectForKey:@"forks"] count];
    NSUInteger watchCount = [[self.repoDetailsData objectForKey:@"watch"] count];
    actionCountStr = [NSString stringWithFormat:@"%@ x %lu\n%@ x %lu",
                      [NSString stringWithUTF8String:"\uf02a"], watchCount,
                      [NSString stringWithUTF8String:"\uf002"], forkCount];
    
    self.numberOfActionsLabel.text = actionCountStr;
    self.repoNameLabel.text = [self.repoDetailsData objectForKey:@"repoName"];
    self.codingLanguageLabel.text = [self.repoDetailsData objectForKey:@"repoLanguage"];
    self.createdAtLabel.text = [dateFormat stringFromDate:date];
    
    // allocate space for avatar images
    _avatarImages = [NSMutableDictionary dictionaryWithCapacity:forkCount + watchCount];
}

#pragma mark - UICollectionViewDataSource

// Return the amount of cells in the selection view;
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [[self.repoDetailsData objectForKey:@"watchers"] count] +
           [[self.repoDetailsData objectForKey:@"forks"] count];
}

// The bulk of the class, builds the cells using the event data to populate the UI elements
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"UserCollectionViewCell" forIndexPath:indexPath];
    
    // determine type and data index
    NSString* typeStr = @"Watched";
    NSArray* dataArray = [self.repoDetailsData objectForKey:@"watchers"];
    NSUInteger dataIndex = indexPath.row;
    GitHubType type = kGitHubType_WatchEvent; 
    if (indexPath.row >= [[self.repoDetailsData objectForKey:@"watchers"] count]) {
        type = kGitHubType_ForkEvent;
        typeStr = @"Forked";
        dataIndex -= [[self.repoDetailsData objectForKey:@"watchers"] count];
        dataArray = [self.repoDetailsData objectForKey:@"forks"];
    }
    
    // lookup the source data
    NSDictionary* sourceData = dataArray[dataIndex];
    NSString* urlKey = sourceData[@"username"];
    UserCollectionViewCell* ucell = (UserCollectionViewCell*)cell;
    
    // Get the date of the action and build the action-date string
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setTimeZone:[NSTimeZone localTimeZone]];
    [dateFormat setDateFormat:@"MMM dd, yyyy"];
    NSDate* date = sourceData[@"date"];
    NSString* actionDateStr = [NSString stringWithFormat:@"%@ %@",
                               typeStr, [dateFormat stringFromDate:date]];
    
    // apply data to the cell
    ucell.actionTakenAndDateLabel.text = actionDateStr;
    ucell.userNameLabel.text = sourceData[@"username"];
    
    // Load the avatar images for each of the collection view cells
    UIImage* avatarImage = [_avatarImages objectForKey:urlKey];
    if (avatarImage == nil) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            NSURL *imageURL = [NSURL URLWithString:urlKey];
            __block NSData *imageData;
                           
            dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                // request the image
                imageData = [NSData dataWithContentsOfURL:imageURL];
                                             
                dispatch_sync(dispatch_get_main_queue(),
                ^{
                    ucell.userAvatarImageView.image = [UIImage imageWithData:imageData];
                    [_avatarImages setValue:ucell.userAvatarImageView.image forKey:urlKey];
                });
            });
        });
    }
    else {
        // we have already downloaded this image prior, so
        // a simple assignment is all we need
        ucell.userAvatarImageView.image = avatarImage;
    }
    
    return cell;
}

// Return only 1 section fot this collection view
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

@end
