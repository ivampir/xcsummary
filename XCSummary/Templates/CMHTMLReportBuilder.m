//
//  CMHTMLReportBuilder.m
//  xcsummary
//
//  Created by Kryvoblotskyi Sergii on 12/13/16.
//  Copyright © 2016 MacPaw inc. All rights reserved.
//

#import "CMHTMLReportBuilder.h"
#import "CMTest.h"
#import "CMTestableSummary.h"
#import "CMActivitySummary.h"
#import "TemplateGeneratedHeader.h"

@interface CMHTMLReportBuilder ()

@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *resultsPath;
@property (nonatomic, copy) NSString *htmlResourcePath;

@property (nonatomic, strong) NSMutableString *resultString;
@property (nonatomic, strong) NSMutableString *developerReportString;
@property (nonatomic, strong) NSMutableString *userReportString;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic) BOOL showSuccessTests;

@property (nonatomic, strong) NSDateComponentsFormatter *timeFormatter;

@end

@implementation CMHTMLReportBuilder

- (instancetype)initWithAttachmentsPath:(NSString *)path
                            resultsPath:(NSString *)resultsPath
                       showSuccessTests:(BOOL)showSuccessTests
{
    self = [super init];
    if (self)
    {
        _fileManager = [NSFileManager defaultManager];
        _path = path;
        _resultsPath = resultsPath;
        _htmlResourcePath = [[resultsPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"resources"];
        _resultString = [NSMutableString new];
        _showSuccessTests = showSuccessTests;
        [self _prepareResourceFolder];
    }
    return self;
}

- (NSDateComponentsFormatter *)timeFormatter
{
    if (!_timeFormatter)
    {
        NSDateComponentsFormatter *formatter = [NSDateComponentsFormatter new];
        formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleAbbreviated;
        formatter.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
        _timeFormatter = formatter;
    }
    return _timeFormatter;
}

#pragma mark - Public

- (void)appendSummaries:(NSArray <CMTestableSummary *> *)summaries
{
    NSUInteger successfullTests = [[summaries valueForKeyPath:@"@sum.numberOfSuccessfulTests"] integerValue];
    NSUInteger failedTests = [[summaries valueForKeyPath:@"@sum.numberOfFailedTests"] integerValue];
 
    BOOL failuresPresent = failedTests > 0;
    NSString *templateFormat = [self _decodeTemplateWithName:SummaryTemplate];
    NSTimeInterval totalTime = [[summaries valueForKeyPath:@"@sum.totalDuration"] doubleValue];
    NSString *timeString = [self.timeFormatter stringFromTimeInterval:totalTime];
    NSString *header = [NSString stringWithFormat:templateFormat, successfullTests + failedTests, timeString, successfullTests, failuresPresent ? @"inline": @"none", failedTests];
    [self.resultString appendString:header];
}

- (void)appendTests:(NSArray *)tests indentation:(CGFloat)indentation
{
    [tests enumerateObjectsUsingBlock:^(CMTest * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        [self _appendTestCase:obj indentation:indentation];
        if (obj.subTests.count > 0)
        {
            [self appendTests:obj.subTests indentation:indentation + 50];
        }
        else
        {
            if (self.showSuccessTests == NO)
            {
                if (obj.status == CMTestStatusFailure)
                {
                    [self appendTest:obj indentation:indentation];
                }
            }
            else
            {
                [self appendTest:obj indentation:indentation];
            }
            
        }
    }];
}

- (void)appendTest:(CMTest *)test indentation:(CGFloat)indentation
{
    self.developerReportString = [NSMutableString new];
    self.userReportString = [NSMutableString new];
    
    [self _appendBeginingForTest:test];
    [self _appendActivities:test.activities indentation:indentation + 50];
    [self _appendDeveloperReportForTest:test];
    [self _appendUserReportForTest:test];
    [self _appendEndForTest:test];
}

- (NSString *)build
{
    NSString *templateFormat = [self _decodeTemplateWithName:Template];
    return [NSString stringWithFormat:templateFormat, self.resultString.copy];
}

#pragma mark - Private

- (NSString *)_decodeTemplateWithName:(NSString *)fileName
{
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:fileName options:0];
    NSString *format = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
    return format;
}

- (void)_appendTestCase:(CMTest *)testCase indentation:(CGFloat)indentation
{
    NSString *templateFormat = testCase.status == CMTestStatusFailure ?
    [self _decodeTemplateWithName:TestCaseTemplateFailed] :
    [self _decodeTemplateWithName:TestCaseTemplate];
    NSString *composedString = [NSString stringWithFormat:templateFormat, indentation, @"px", testCase.testName, testCase.testName, testCase.duration];
    [self.resultString appendString:composedString];
}

- (void)_appendActivities:(NSArray *)activities indentation:(CGFloat)indentation
{
    [activities enumerateObjectsUsingBlock:^(CMActivitySummary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self _appendActivity:obj indentation:indentation];
        [self _appendActivities:obj.subActivities indentation:indentation + 50];
    }];
}

- (void)_appendActivity:(CMActivitySummary *)activity indentation:(CGFloat)indentation
{
    NSString *templateFormat = nil;
    NSString *composedString = nil;
    if (activity.type == CMActivityTypeEvent)
    {
        templateFormat = [self _decodeTemplateWithName:ActivityTemplateWithImage];
        NSString *imageName = [NSString stringWithFormat:@"Screenshot_%@.png", activity.uuid.UUIDString];
        NSString *fullPath = [self.path stringByAppendingPathComponent:imageName];
        
        [self.fileManager copyItemAtPath:fullPath toPath:[self.htmlResourcePath stringByAppendingPathComponent:imageName] error:nil];
        
        NSString *localImageName = [NSString stringWithFormat:@"resources/Screenshot_%@.png", activity.uuid.UUIDString];
        composedString = [NSString stringWithFormat:templateFormat, activity.title, activity.finishTimeInterval - activity.startTimeInterval, localImageName, localImageName];
        [self.resultString appendString:composedString];
    }
    else if (activity.type == CMActivityTypeLog)
    {
        [self.userReportString appendString:activity.userLog];
        [self.userReportString appendString:@"<br>"];
    }
    
    NSString *descriptionString = [NSString stringWithFormat:@"%@ (%2.2f sec)<br>", activity.title, activity.finishTimeInterval - activity.startTimeInterval];
    [self.developerReportString appendString:descriptionString];
}

- (void)_appendBeginingForTest:(CMTest *)test
{
    NSString *testBegining = [NSString stringWithFormat:@"<div id=\"%@\" style=\"display: none\" margin-left: 10.00px; background-color: #CBF4A3; padding:10px; text-align: right;>", test.testName];
    [self.resultString appendString:testBegining];
}

- (void)_appendDeveloperReportForTest:(CMTest *)test
{
    NSString *reportId = [NSString stringWithFormat:@"%@DevReport", test.testName];
    NSString *reportLink = [NSString stringWithFormat:@"<br><br><a onclick=\"javascript:toggle('%@');\">Developer Report</a><br>", reportId];
    NSString *report = [NSString stringWithFormat:@"<div id=\"%@\" style=\"display: none\" margin-left: 10.00px; background-color: #CBF4A3; padding:10px; text-align: right;>%@</div>", reportId, self.developerReportString];
    [self.resultString appendString:reportLink];
    [self.resultString appendString:report];
}

- (void)_appendUserReportForTest:(CMTest *)test
{
    NSString *reportId = [NSString stringWithFormat:@"%@UserReport", test.testName];
    NSString *reportLink = [NSString stringWithFormat:@"<br><br><a onclick=\"javascript:toggle('%@');\">User Report</a><br>", reportId];
    NSString *report = [NSString stringWithFormat:@"<div id=\"%@\" style=\"display: none\" margin-left: 10.00px; background-color: #CBF4A3; padding:10px; text-align: right;>%@</div>", reportId, self.userReportString];
    [self.resultString appendString:reportLink];
    [self.resultString appendString:report];
}

- (void)_appendEndForTest:(CMTest *)test
{
    [self.resultString appendString:@"</div>"];
}

#pragma mark - File Operations

- (void)_prepareResourceFolder
{
    if ([self.fileManager fileExistsAtPath:self.htmlResourcePath] == NO) {
        [self.fileManager createDirectoryAtPath:self.htmlResourcePath withIntermediateDirectories:NO attributes:nil error:nil];
    }
}

@end
