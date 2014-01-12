//
//  MPGesturesIntegrationTests.m
//  MPGestures
//
//  Created by Matias Piipari on 11/01/2014.
//  Copyright (c) 2014 de.ur. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "MPStrokeSequenceDatabase.h"
#import "MPStrokeSequence.h"
#import "MPStroke.h"
#import "MPPoint.h"
#import "MPDollarPointCloudRecognizer.h"

#import "MPStrokeSequenceDatabaseSynchronizer.h"

@interface MPStrokeSequenceDatabaseSynchronizer ()
@property (readwrite) BOOL synchronousRequests;
@end

@interface MPContinuousGestureSyncIntegrationTests : XCTestCase
@property (readwrite) MPStrokeSequenceDatabase *db;
@property (readwrite) MPStrokeSequence *seq;
@end

@implementation MPContinuousGestureSyncIntegrationTests

- (void)setUp
{
    [super setUp];
    
    self.db = [[MPStrokeSequenceDatabase alloc] initWithIdentifier:@"foobar"];
    
    self.seq = [[MPStrokeSequence alloc] initWithDictionary:@{@"name":@"Foobar"}];
    MPStroke *stroke1 = [[MPStroke alloc] initWithDictionary:@{}];
    MPStroke *stroke2 = [[MPStroke alloc] initWithDictionary:@{}];
    
    [stroke1 addPoint:CGPointMake(3,4) identifier:1];
    [stroke1 addPoint:CGPointMake(5,2) identifier:1];
    [stroke1 addPoint:CGPointMake(7,1) identifier:1];
    
    [stroke2 addPoint:CGPointMake(5,4) identifier:2];
    [stroke2 addPoint:CGPointMake(2,4) identifier:2];
    [stroke2 addPoint:CGPointMake(1,2) identifier:2];
    
    [self.seq addStroke:stroke1];
    [self.seq addStroke:stroke2];
    
    MPStrokeSequenceDatabaseSynchronizer *service = [MPStrokeSequenceDatabaseSynchronizer sharedInstance];
    [service continuouslySynchronizeDatabase:self.db];
    
    // without this the continuous synchronisation happens async in background.
    [service setSynchronousRequests:YES];
    
    NSError *err = nil;

    NSArray *foundSeqs = [service strokeSequencesWithSignature:self.seq.signature
                                      inDatabaseWithIdentifier:self.db.identifier
                                                         error:&err];
    XCTAssertTrue(foundSeqs.count == 0, @"No stroke sequences were found prior to insertion.");
    
    [self.db addStrokeSequence:self.seq];
    
    foundSeqs = [service strokeSequencesWithSignature:self.seq.signature
                             inDatabaseWithIdentifier:self.db.identifier
                                                error:&err];
    XCTAssertTrue(foundSeqs.count == 1, @"A stroke sequence was found");
    XCTAssertTrue([[foundSeqs firstObject] isEqual:self.seq],
                  @"The stroke sequence has made a successful roundtrip.");
}

- (void)tearDown
{
    [super tearDown];
    
    [self _tearDownWithAssertions:YES];
}

// a helper method that's used both for tearDown (called with YES as argument then)
// and as part of setUp to initially clean the database (called with NO as argument then).
- (void)_tearDownWithAssertions:(BOOL)assertTruths
{
    
    MPStrokeSequenceDatabaseSynchronizer *service = [MPStrokeSequenceDatabaseSynchronizer sharedInstance];
    
    NSError *err = nil;
    
    NSArray *databaseIdentifiers = [service databaseIdentifiersWithError:&err];
    
    if (assertTruths) {
        XCTAssertNotNil(databaseIdentifiers, @"Database identifiers were found.");
        XCTAssertTrue([[NSSet setWithArray:databaseIdentifiers] isEqual:
                       [NSSet setWithArray:@[@"foobar"]]],
                      @"Database identifier set matches expectation before deletion");
    }
    
    for (NSString *identifier in databaseIdentifiers)
    {
        NSError *e = nil;
        MPStrokeSequenceDatabase *db = [service databaseWithIdentifier:identifier error:&e];
        
        XCTAssertNotNil(db, @"A database could be instantiated.");
        
        for (MPStrokeSequence *seq in [db strokeSequenceSet])
        {
            NSError *remerr = nil;
            BOOL removalSuccessful = [service removeStrokeSequence:seq fromDatabase:db error:&remerr];
            
            if (assertTruths)
                XCTAssertTrue(removalSuccessful, @"Removing stroke sequence succeeded.");
        }
    }
}

- (void)testListingSynchronizerServiceDatabaseContents
{
    MPStrokeSequenceDatabaseSynchronizer *service = [MPStrokeSequenceDatabaseSynchronizer sharedInstance];
    
    NSError *err = nil;
    MPStrokeSequenceDatabase *db = [service databaseWithIdentifier:@"mpgestures" error:&err];
    
    XCTAssertNotNil(db, @"A database was successfully created.");
    XCTAssertTrue(db.strokeSequenceSet.count == 1,
                  @"There is an expected number of items in the created database.");
    XCTAssertTrue([db.strokeSequenceSet isEqualToSet:self.db.strokeSequenceSet],
                  @"The parsed stroke sequences are equal to the input (successful roundtrip).");
}

@end
