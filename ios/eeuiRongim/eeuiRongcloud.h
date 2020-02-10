//
//  eeuiRongcloud.h
//
//  Created by 高一 on 2019/3/1.
//

#import <Foundation/Foundation.h>

static NSString *rongKey;
static NSString *rongSec;

NS_ASSUME_NONNULL_BEGIN

@interface eeuiRongcloud : NSObject

+ (instancetype)sharedManager;
+ (NSString*) getRongKey;
+ (NSString*) getRongSec;

@end

NS_ASSUME_NONNULL_END
