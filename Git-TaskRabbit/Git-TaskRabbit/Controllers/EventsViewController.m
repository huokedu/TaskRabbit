#import "AppDelegate.h"
#import "EventsViewController.h"
#import "EventCollectionViewCell.h"
#import "GitHubEventData.h"
#import "RepoDetailViewController.h"

@implementation EventsViewController

// allocate any resources needed for building this collection-view
- (void)viewDidLoad {
    [super viewDidLoad];
    UINib *nib = [UINib nibWithNibName:@"EventCollectionViewCell" bundle:nil];
    [self.collectionView registerNib:nib forCellWithReuseIdentifier:@"EventCollectionViewCell"];
    
    AppDelegate* appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    _sourceData = [appDelegate fetchEvents:@""];
    _avatarImages = [NSMutableDictionary dictionaryWithCapacity:[_sourceData count]];
    
    // Check if we have enough data to scroll infinitely
    UICollectionViewCell* rootView = [[nib instantiateWithOwner:nil options:nil] lastObject];
    _cellHeight = rootView.contentView.frame.size.height;
    _contentHeight = _cellHeight * [_sourceData count];
    
    CGFloat contentViewHeight = self.collectionView.frame.size.height;
    if (contentViewHeight < _cellHeight * [_sourceData count])
    {
        _canInfinitelyScroll = YES;
    }
}

// Sets the title for this view controller
- (NSString *)title {
    return @"Stream";
}

#pragma mark - UICollectionViewDataSource
// Return the number of cells this view will have
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)sectio
{
    return _canInfinitelyScroll ? [_sourceData count] * 2 : [_sourceData count];
}

// The heart and guts of this class that is responsible for the building all of the cells
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {

    // need this to lookup font
    AppDelegate* appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    
    // Recycle, get new cells or used ones if we have them available
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"EventCollectionViewCell" forIndexPath:indexPath];
    
    // Grab the detals that we care about to customize the cell
    NSUInteger dataRow = indexPath.row % [_sourceData count];
    NSManagedObject* obj = _sourceData[dataRow];
    NSString* urlKey = [obj valueForKey:@"avatarURL"];
    GitHubType type = (GitHubType)[[obj valueForKey:@"type"] intValue];
    
    // Format the date
    NSDateFormatter* dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setTimeZone:[NSTimeZone localTimeZone]];
    [dateFormat setDateFormat:@"MMM dd, yyyy"];
    NSDate* date = [obj valueForKey:@"timeStamp"];
    
    // Grab the details for the repo based on this guy
    NSMutableDictionary* repoDetails = [obj valueForKey:@"repoDetails"];
    
    // Build the cell details to customize the appearance based on the
    // values stored within the model
    EventCollectionViewCell* ecell = (EventCollectionViewCell*)cell;
    ecell.repoNameLabel.text = [repoDetails objectForKey:@"repoName"];
    ecell.dateLabel.text = [dateFormat stringFromDate:date];
    ecell.userAvatarImageView.image = [_avatarImages objectForKey:urlKey];
    ecell.userNameLabel.text = [obj valueForKey:@"userName"];
    ecell.actionTakenLabel.font = appDelegate.octiconsFont;
    
    // set the icon str based on event type
    switch (type) {
        case kGitHubType_ForkEvent:
            ecell.actionTakenLabel.text = [NSString stringWithUTF8String:"\uf002"];
            break;
        case kGitHubType_WatchEvent:
            ecell.actionTakenLabel.text = [NSString stringWithUTF8String:"\uf02a"];
            break;
        case kGitHubType_UnknownEvent:
            ecell.actionTakenLabel.text = [NSString stringWithUTF8String:"\uf02c"];
            break;
    }
    
    // NOTE:
    // To avoid any stutters and unpleasant pauses during the building
    // of this collection view, we load all images asynchrounously
    
    // Load the avatar images for each of the collection view cells
    UIImage* avatarImage = [_avatarImages objectForKey:urlKey];
    if (avatarImage == nil) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            NSURL *imageURL = [NSURL URLWithString:urlKey];
            __block NSData *imageData;
                           
            dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                imageData = [NSData dataWithContentsOfURL:imageURL];
                
                dispatch_sync(dispatch_get_main_queue(),
                ^{
                    ecell.userAvatarImageView.image = [UIImage imageWithData:imageData];
                    [_avatarImages setValue:ecell.userAvatarImageView.image forKey:urlKey];
                });
            });
        });
    }
    else {
        // we have already downloaded this image prior, so
        // a simple assignment is all we need
        ecell.userAvatarImageView.image = avatarImage;
    }
    
    // return the new cell
    return cell;
}

// How many sections does this collection view have
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

#pragma mark - UICollectionViewDelegate

// Handle when the user collects on a cell
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    RepoDetailViewController* viewController = [RepoDetailViewController new];
    viewController.repoDetailsData = [_sourceData[indexPath.row] valueForKey:@"repoDetails"];
    
    [self.navigationController pushViewController:viewController animated:YES];
}

@end
