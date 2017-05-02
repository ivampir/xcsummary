//
//  CMActivitySummary.m
//  xcsummary
//
//  Created by Kryvoblotskyi Sergii on 12/12/16.
//  Copyright © 2016 MacPaw inc. All rights reserved.
//

#import "CMActivitySummary.h"
#import "NSArrayAdditions.h"

static NSString *kEventTitle = @"Synthesize event";

@implementation CMActivitySummary

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self)
    {
        NSString *uuidString = dictionary[@"UUID"];
        NSArray *subActivitesInfo = dictionary[@"SubActivities"];
        _title = dictionary[@"Title"];
        _uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
        _startTimeInterval = [dictionary[@"StartTimeInterval"] doubleValue];
        _finishTimeInterval = [dictionary[@"FinishTimeInterval"] doubleValue];
        _hasScreenshotData = [dictionary[@"HasScreenshotData"] boolValue];
        _hasElementsOfInterest = [dictionary[@"HasElementsOfInterest"] boolValue];
        _type = [self typeForTitle:_title];
        _subActivities = [subActivitesInfo map:^id(NSDictionary *activityInfo, NSUInteger index, BOOL *stop) {
            return [[CMActivitySummary alloc] initWithDictionary:activityInfo];
        }];
    }
    return self;
}

- (CMActivityType)typeForTitle:(NSString *)title
{
    CMActivityType type = CMActivityTypeUnknown;
    if ([title isEqualToString:kEventTitle])
    {
        type = CMActivityTypeEvent;
    }
    
    return type;
}

@end
