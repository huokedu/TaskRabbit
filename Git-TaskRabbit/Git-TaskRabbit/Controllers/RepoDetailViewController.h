#import <UIKit/UIKit.h>

@interface RepoDetailViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate>
{
    NSMutableDictionary* _avatarImages;
}

@property (nonatomic, weak) IBOutlet UICollectionView *collectionView;
@property (nonatomic, weak) IBOutlet UILabel *repoNameLabel;
@property (nonatomic, weak) IBOutlet UILabel *codingLanguageLabel;
@property (nonatomic, weak) IBOutlet UILabel *createdAtLabel;
@property (nonatomic, weak) IBOutlet UILabel *numberOfActionsLabel;
@property NSDictionary* repoDetailsData;

@end

