#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface RVLocalModel : NSObject
- (nullable instancetype)initWithPath:(NSString *)path error:(NSError **)error;
- (nullable NSString *)generate:(NSString *)prompt error:(NSError **)error;
- (void)cancel;
@end
NS_ASSUME_NONNULL_END
