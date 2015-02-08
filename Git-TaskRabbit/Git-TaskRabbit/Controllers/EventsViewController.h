#import <UIKit/UIKit.h>

@interface EventsViewController : UICollectionViewController <UIScrollViewDelegate>
{
    NSArray* _sourceData;
    NSMutableDictionary* _avatarImages;
    BOOL _canInfinitelyScroll;
    CGFloat _cellHeight;
    CGFloat _contentHeight;
}
@end
