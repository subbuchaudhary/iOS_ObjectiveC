//
//  MISurveyManager.m
//  SqlLiteDemo
//
//  Created by Anil Godawat on 18/02/17.
//  Copyright © 2017 devness. All rights reserved.
//

#import "MISurveyManager.h"
#import "MIConstant.h"
const NSString* MI_ENCRYPTION_KEY= @"MI-MarketIntelligence";

@implementation MISurveyManager
-(id)init
{
    self = [super init];
    self.sales = [self fetchSurveyTypeWithName:@"Sales Opportunity"];
    self.custExp = [self fetchSurveyTypeWithName:@"Customer Experience"];
    if (self.sales ==nil ||self.custExp ==nil) {
        
        [MIDBManager getSharedInstance];
        
        self.sales = [[MISurveyType alloc] init];
        self.sales.surveyId = [NSNumber numberWithInt:1];
        self.sales.surveyName = @"Sales Opportunity";
        self.sales.superCategory = [NSSet setWithArray:[self createSalesSuperCategory]];
        [[MIDBManager getSharedInstance] setSurveyType:self.sales];
        [[MIDBManager getSharedInstance] createCategoryStructureInDatabase];
        
        self.custExp = [[MISurveyType alloc] init];
        self.custExp.surveyId = [NSNumber numberWithInt:2];
        self.custExp.surveyName = @"Customer Experience";
        self.custExp.superCategory = [NSSet setWithArray:[self createCustomerExpSuperCategory]];
        [[MIDBManager getSharedInstance] setSurveyType:self.custExp];
        [[MIDBManager getSharedInstance] createCategoryStructureInDatabase];
        
        self.sales =  [[MIDBManager getSharedInstance] getSurveyRecordsFromSurveyId:1];
        self.custExp  = [[MIDBManager getSharedInstance] getSurveyRecordsFromSurveyId:2];
        [self saveCurrentSurvey];
    }
    else
    {
        self.sales =  [[MIDBManager getSharedInstance] getSurveyRecordsFromSurveyId:1];
        self.custExp  = [[MIDBManager getSharedInstance] getSurveyRecordsFromSurveyId:2];
    }
    [self loadDealerlist];
    return self;
}

#pragma mark - LOAD DEALER LIST 
-(void)loadDealerlist
{
    self.dealerList = [[MIDBManager getSharedInstance]fetchDealerList];
    if (self.dealerList.count==0) {
        self.dealerList = [[NSMutableArray alloc] initWithCapacity:10];
    }
    else
    {
        for (MIDealerList *dealer in self.dealerList)
        {
            [dealer decryptWithKey:MI_ENCRYPTION_KEY];
        }
    }
    NSMutableArray *dealSummeryList = [[MIDBManager getSharedInstance] fetchDealerSummery];
    
}

- (void) clearCurrentDealers
{
    [[MIDBManager getSharedInstance] deleteDealerlist];
    [self saveCurrentSurvey];
}




#pragma mark - CREATE SUPER CATEGORY
-(NSArray*)createSalesSuperCategory
{
    //1:Sales Opportunity super category
    MISuperCategory *superCat1 = [[MISuperCategory alloc] init];
    superCat1.surveyId = [NSNumber numberWithInt:1];
    superCat1.superCatId = [NSNumber numberWithInt:1];
    superCat1.superCatName = @"Customer Retention";
    superCat1.categorylist = [NSSet setWithArray:[self createCustomerRetentionCategorySubCategory]];
    
    MISuperCategory *superCat2  = [[MISuperCategory alloc] init];
    superCat2.surveyId = [NSNumber numberWithInt:1];
    superCat2.superCatId = [NSNumber numberWithInt:2];
    superCat2.superCatName = @"Flooring Opportunity";
    superCat2.categorylist = [NSSet setWithArray:[self createFlooringOpportunityWithSuperCategoryId:superCat2.superCatId]];

    MISuperCategory *superCat3  = [[MISuperCategory alloc] init];
    superCat3.surveyId = [NSNumber numberWithInt:1];
    superCat3.superCatId = [NSNumber numberWithInt:3];
    superCat3.superCatName = @"Credit Line Increase";
    superCat3.categorylist = [NSSet setWithArray:[self createCreditLineIncreaseWithSuperCategoryId:superCat3.superCatId]];
    return @[superCat1,superCat2,superCat3];
}
-(NSArray*)createCustomerExpSuperCategory
{
    //2:Customer Experience super category
    MISuperCategory *custSuperCat = [[MISuperCategory alloc] init];
    custSuperCat.surveyId = [NSNumber numberWithInt:2];
    custSuperCat.superCatId = [NSNumber numberWithInt:5];
    custSuperCat.superCatName = @"CX";
    custSuperCat.categorylist = [NSSet setWithArray:[self createCXCategorySubCategoryWithSuperCatid:custSuperCat]];
    return @[custSuperCat];
}
#pragma mark - CREATE CATEGORY AND SUBCATEGORY
-(NSArray*)createCustomerRetentionCategorySubCategory
{
    //Caterory 1
    MICategory *pricing = [[MICategory alloc] init];
    pricing.surveyId = [NSNumber numberWithInt:1];
    pricing.superCatId = [NSNumber numberWithInt:1];
    pricing.catId   = [NSNumber numberWithInt:1];
    pricing.catName = @"Pricing (Rates/Structure)";
    NSArray *subCatNames = @[@"FFP/Credit Line Utilization",@"Interest Rate",@"OEM Agreement",@"Due in Full",@"Curtailments",@"Other"];
    NSMutableArray *subCategory = [[NSMutableArray alloc] init];
    for (int i = 0; i<subCatNames.count; i++) {
        MISubCategory *subPriceCat1 = [[MISubCategory alloc] init];
        subPriceCat1.surveyId = [NSNumber numberWithInt:1];
        subPriceCat1.superCatId = [NSNumber numberWithInt:1];
        subPriceCat1.catId = pricing.catId;
        subPriceCat1.subCatId = [NSNumber numberWithInt:i+1];
        subPriceCat1.subCatName = subCatNames[i];
        [subCategory addObject:subPriceCat1];
    }
    pricing.subCategorylist = [NSSet setWithArray:subCategory];
    
    //Category 2
    MICategory *ownershipChange = [[MICategory alloc] init];
    ownershipChange.surveyId = [NSNumber numberWithInt:1];
    ownershipChange.superCatId = [NSNumber numberWithInt:1];
    ownershipChange.catId   = [NSNumber numberWithInt:2];
    ownershipChange.catName = @"Change Of Ownership";
    
    //Category3
    MICategory *competitiveThreat = [[MICategory alloc] init];
    competitiveThreat.surveyId = [NSNumber numberWithInt:1];
    competitiveThreat.superCatId = [NSNumber numberWithInt:1];
    competitiveThreat.catId   = [NSNumber numberWithInt:3];
    competitiveThreat.catName = @"Competitive Threat";
    NSArray *competSubCatArray = @[@{@"id":[NSNumber numberWithInt:8],@"name":@"Customer Satisfaction"},@{@"id":[NSNumber numberWithInt:11],@"name":@"Technology/Amenities"},@{@"id":[NSNumber numberWithInt:12],@"name":@"Adverse Media"},@{@"id":[NSNumber numberWithInt:13],@"name":@"Local Bank/Finance Company"},@{@"id":[NSNumber numberWithInt:14],@"name":@"Other"}];
    NSMutableArray *subCategory1 = [[NSMutableArray alloc] init];
    for (NSDictionary *dict in competSubCatArray) {
        MISubCategory *subPriceCat1 = [[MISubCategory alloc] init];
        subPriceCat1.surveyId = [NSNumber numberWithInt:1];
        subPriceCat1.superCatId = [NSNumber numberWithInt:1];
        subPriceCat1.catId = competitiveThreat.catId;
        subPriceCat1.subCatId = dict[@"id"];
        subPriceCat1.subCatName = dict[@"name"];
        if ([subPriceCat1.subCatId intValue] == 8) {
            NSArray *topicArray = @[@{@"id":[NSNumber numberWithInt:9],@"name":@"Miscommunication (Non GE)"},@{@"id":[NSNumber numberWithInt:10],@"name":@"Policies And Procedures"},@{@"id":[NSNumber numberWithInt:11],@"name":@"Ease Of Doing Business"}];
            NSMutableArray *topiclist = [[NSMutableArray alloc] init];
            for (NSDictionary *topicDict in topicArray) {
                MITopic* st1 = [[MITopic alloc] init];
                st1.surveyId = subPriceCat1.surveyId;
                st1.superCatId = subPriceCat1.superCatId;
                st1.catId = subPriceCat1.catId;
                st1.subCatId = subPriceCat1.subCatId;
                st1.topicid = topicDict[@"id"];
                st1.topicName = topicDict[@"name"];
                [topiclist addObject:st1];
            }
            subPriceCat1.topiclist = [NSSet setWithArray:topiclist];
        }
        
        [subCategory1 addObject:subPriceCat1];
    }
    competitiveThreat.subCategorylist  = [NSSet setWithArray:subCategory1];
    return @[pricing,ownershipChange,competitiveThreat];
}

-(NSArray*)createFlooringOpportunityWithSuperCategoryId:(NSNumber*)superCategoryId
{
    NSArray *categoryNames = @[@"New Product Line",@"Open Account",@"Buyout Opportunity",@"Pre-Owned",@"Rental Program",@"NRD - New Market Growth",@"NRD - New Products",@"NRD - Existing Market Growth"];
    int catId = 14;
    NSMutableArray *categorylist = [[NSMutableArray alloc] init];
    for (NSString* name in categoryNames) {
        MICategory *flooring = [[MICategory alloc] init];
        flooring.surveyId = [NSNumber numberWithInt:1];
        flooring.superCatId = superCategoryId;
        flooring.catId   = [NSNumber numberWithInt:catId++];
        flooring.catName = name;
        [categorylist addObject:flooring];
    }
    return categorylist;
}

- (NSArray*)createCreditLineIncreaseWithSuperCategoryId:(NSNumber*)superCategoryId
{
    NSArray *categoryNames = @[@"Redistribution Of Credit Line",@"Increase Of Specific OEM",@"Temporary Increase",@"Asset Backed Lending",@"Short Term A/R"];
    
    NSArray *subCategoryName = @[@"Special Circumstance",@"Seasonal",@"Other"];
    
    NSMutableArray *categorylist = [[NSMutableArray alloc] init];
    int catId = 22;
    for (NSString *categoryName in categoryNames) {
        MICategory *flooring = [[MICategory alloc] init];
        flooring.surveyId = [NSNumber numberWithInt:1];
        flooring.superCatId = superCategoryId;
        flooring.catId  = [NSNumber numberWithInt:catId++];
        flooring.catName = categoryName;
        if ([categoryName isEqualToString:@"Temporary Increase"]) {
            NSMutableArray *subArray = [[NSMutableArray alloc] init];
            for (NSString *subCatName in subCategoryName) {
                MISubCategory *subPriceCat1 = [[MISubCategory alloc] init];
                subPriceCat1.surveyId = [NSNumber numberWithInt:1];
                subPriceCat1.superCatId = superCategoryId;
                subPriceCat1.catId = flooring.catId;
                subPriceCat1.subCatId = [NSNumber numberWithInt:catId++];
                subPriceCat1.subCatName = subCatName;
                [subArray addObject:subPriceCat1];
            }
            flooring.subCategorylist    = [NSSet setWithArray:subArray];
        }
        [categorylist addObject:flooring];
    }
    return categorylist;
}


-(NSArray*)createCXCategorySubCategoryWithSuperCatid:(MISuperCategory *)superCategory
{
    MICategory *CX_cat1 = [[MICategory alloc] init];
    CX_cat1.surveyId = superCategory.surveyId;
    CX_cat1.superCatId = superCategory.superCatId;
    int catId = 32;
    CX_cat1.catId  = [NSNumber numberWithInt:catId++];
    CX_cat1.catName = @"Timely Response";
    NSArray *CXsubCatArray1 = @[@"Returned Calls",@"Issue Resolution",@"Other"];
    NSMutableArray *CXSubCatModelArray1 = [[NSMutableArray alloc] init];
    for (NSString* CXCatName in CXsubCatArray1) {
        MISubCategory *cxSubCategory = [[MISubCategory alloc] init];
        cxSubCategory.surveyId = superCategory.surveyId;
        cxSubCategory.superCatId = superCategory.superCatId;
        cxSubCategory.catId = CX_cat1.catId;
        cxSubCategory.subCatId = [NSNumber numberWithInt:catId++];
        cxSubCategory.subCatName = CXCatName;
        [CXSubCatModelArray1 addObject:cxSubCategory];
    }
    CX_cat1.subCategorylist = [NSSet setWithArray:CXSubCatModelArray1];
    [CXSubCatModelArray1 removeAllObjects];

    //Second category
    MICategory *CX_cat2 = [[MICategory alloc] init];
    CX_cat2.surveyId = superCategory.surveyId;
    CX_cat2.superCatId = superCategory.superCatId;
    CX_cat2.catId  = [NSNumber numberWithInt:catId++];
    CX_cat2.catName = @"General Customer Service";
    NSArray *CXsubCatArray2 = @[@"Account Manager",@"Field Services",@"Commercial",@"OEM",@"Other"];
    for (NSString* CXCatName in CXsubCatArray2) {
        MISubCategory *cxSubCategory = [[MISubCategory alloc] init];
        cxSubCategory.surveyId = superCategory.surveyId;
        cxSubCategory.superCatId = superCategory.superCatId;
        cxSubCategory.catId = CX_cat2.catId;
        cxSubCategory.subCatId = [NSNumber numberWithInt:catId++];
        cxSubCategory.subCatName = CXCatName;
        [CXSubCatModelArray1 addObject:cxSubCategory];
    }
    CX_cat2.subCategorylist = [NSSet setWithArray:CXSubCatModelArray1];
    [CXSubCatModelArray1 removeAllObjects];

    //Third category
    MICategory *CX_cat3 = [[MICategory alloc] init];
    CX_cat3.surveyId = superCategory.surveyId;
    CX_cat3.superCatId = superCategory.superCatId;
    CX_cat3.catId  = [NSNumber numberWithInt:catId++];
    CX_cat3.catName = @"COMS";
    NSArray *CXsubCatArray3 = @[@"Issue",@"Enhancement",@"Commercial",@"Other"];
    for (NSString* CXCatName in CXsubCatArray3) {
        MISubCategory *cxSubCategory = [[MISubCategory alloc] init];
        cxSubCategory.surveyId = superCategory.surveyId;
        cxSubCategory.superCatId = superCategory.superCatId;
        cxSubCategory.catId = CX_cat3.catId;
        cxSubCategory.subCatId = [NSNumber numberWithInt:catId++];
        cxSubCategory.subCatName = CXCatName;
        [CXSubCatModelArray1 addObject:cxSubCategory];
    }
    CX_cat3.subCategorylist = [NSSet setWithArray:CXSubCatModelArray1];
    [CXSubCatModelArray1 removeAllObjects];
    
    //Fourth Category
    MICategory *CX_cat4 = [[MICategory alloc] init];
    CX_cat4.surveyId = superCategory.surveyId;
    CX_cat4.superCatId = superCategory.superCatId;
    CX_cat4.catId  = [NSNumber numberWithInt:catId++];
    CX_cat4.catName = @"Ease Of Doing Business";
    NSArray *CXsubCatArray4 = @[@"Documentation",@"Structure",@"Other"];
    for (NSString* CXCatName in CXsubCatArray4) {
        MISubCategory *cxSubCategory = [[MISubCategory alloc] init];
        cxSubCategory.surveyId = superCategory.surveyId;
        cxSubCategory.superCatId = superCategory.superCatId;
        cxSubCategory.catId = CX_cat4.catId;
        cxSubCategory.subCatId = [NSNumber numberWithInt:catId++];
        cxSubCategory.subCatName = CXCatName;
        [CXSubCatModelArray1 addObject:cxSubCategory];
        if ([cxSubCategory.subCatName isEqualToString:@"Structure"]) {
            NSMutableArray *topicArray = [[NSMutableArray alloc] init];
            for (int i=0; i<2; i++) {
                MITopic *topic = [[MITopic alloc] init];
                topic.surveyId = superCategory.surveyId;
                topic.superCatId = superCategory.superCatId;
                topic.catId = CX_cat4.catId;
                topic.subCatId = cxSubCategory.subCatId;
                topic.topicid = [NSNumber numberWithInt:catId++];
                topic.topicName = (i==0)?@"Multiple Touches":@"OEM Programs";
                [topicArray addObject:topic];
            }
            [cxSubCategory setTopiclist:[NSSet setWithArray:topicArray]];
            topicArray = nil;
        }
    }
    CX_cat4.subCategorylist = [NSSet setWithArray:CXSubCatModelArray1];
    [CXSubCatModelArray1 removeAllObjects];
    
    //Fifth Category
    MICategory *CX_cat5 = [[MICategory alloc] init];
    CX_cat5.surveyId = superCategory.surveyId;
    CX_cat5.superCatId = superCategory.superCatId;
    CX_cat5.catId  = [NSNumber numberWithInt:catId++];
    CX_cat5.catName = @"Purchasing/Invoicing";
    NSArray *CXsubCatArray5 = @[@"Pre-Approved Coding (Demo Etc.)",@"Model/Serial Numbers",@"Billing Corrections",@"Other"];
    for (NSString* CXCatName in CXsubCatArray5) {
        MISubCategory *cxSubCategory = [[MISubCategory alloc] init];
        cxSubCategory.surveyId = superCategory.surveyId;
        cxSubCategory.superCatId = superCategory.superCatId;
        cxSubCategory.catId = CX_cat5.catId;
        cxSubCategory.subCatId = [NSNumber numberWithInt:catId++];
        cxSubCategory.subCatName = CXCatName;
        [CXSubCatModelArray1 addObject:cxSubCategory];
    }
    CX_cat5.subCategorylist = [NSSet setWithArray:CXSubCatModelArray1];
    [CXSubCatModelArray1 removeAllObjects];
    
    //Sixth category
    MICategory *CX_cat6 = [[MICategory alloc] init];
    CX_cat6.surveyId = superCategory.surveyId;
    CX_cat6.superCatId = superCategory.superCatId;
    CX_cat6.catId  = [NSNumber numberWithInt:catId++];
    CX_cat6.catName = @"Cash Application";
    NSArray *CXsubCatArray6 = @[@"Trade Ins",@"Refunds",@"Credit Memo Delays",@"Other"];
    for (NSString* CXCatName in CXsubCatArray6) {
        MISubCategory *cxSubCategory = [[MISubCategory alloc] init];
        cxSubCategory.surveyId = superCategory.surveyId;
        cxSubCategory.superCatId = superCategory.superCatId;
        cxSubCategory.catId = CX_cat6.catId;
        cxSubCategory.subCatId = [NSNumber numberWithInt:catId++];
        cxSubCategory.subCatName = CXCatName;
        [CXSubCatModelArray1 addObject:cxSubCategory];
    }
    CX_cat6.subCategorylist = [NSSet setWithArray:CXSubCatModelArray1];
    [CXSubCatModelArray1 removeAllObjects];
    
    //Seventh Category
    MICategory *CX_cat7 = [[MICategory alloc] init];
    CX_cat7.surveyId = superCategory.surveyId;
    CX_cat7.superCatId = superCategory.superCatId;
    CX_cat7.catId  = [NSNumber numberWithInt:catId++];
    CX_cat7.catName = @"Manufacturing Escalations";
    NSArray *CXsubCatArray7 = @[@"Shipment Delays",@"Unidentifiable Inventory",@"Other"];
    for (NSString* CXCatName in CXsubCatArray7) {
        MISubCategory *cxSubCategory = [[MISubCategory alloc] init];
        cxSubCategory.surveyId = superCategory.surveyId;
        cxSubCategory.superCatId = superCategory.superCatId;
        cxSubCategory.catId = CX_cat7.catId;
        cxSubCategory.subCatId = [NSNumber numberWithInt:catId++];
        cxSubCategory.subCatName = CXCatName;
        [CXSubCatModelArray1 addObject:cxSubCategory];
        if ([cxSubCategory.subCatName isEqualToString:@"Unidentifiable Inventory"]) {
            NSMutableArray *topicArray = [[NSMutableArray alloc] init];
            MITopic *topic = [[MITopic alloc] init];
            topic.surveyId = superCategory.surveyId;
            topic.superCatId = superCategory.superCatId;
            topic.catId = CX_cat7.catId;
            topic.subCatId = cxSubCategory.subCatId;
            topic.topicid = [NSNumber numberWithInt:catId++];
            topic.topicName = @"Inventory Label Issues";
            [topicArray addObject:topic];
            
            MITopic *topic1 = [[MITopic alloc] init];
            topic1.surveyId = superCategory.surveyId;
            topic1.superCatId = superCategory.superCatId;
            topic1.catId = CX_cat7.catId;
            topic1.subCatId = cxSubCategory.subCatId;
            topic1.topicid = [NSNumber numberWithInt:catId++];
            topic1.topicName = @"Serial Number Location Visibility";
            [topicArray addObject:topic1];
            //@"Unverifiable Line Items"
            
            MITopic *topic2 = [[MITopic alloc] init];
            topic2.surveyId = superCategory.surveyId;
            topic2.superCatId = superCategory.superCatId;
            topic2.catId = CX_cat7.catId;
            topic2.subCatId = cxSubCategory.subCatId;
            topic2.topicid = [NSNumber numberWithInt:catId++];
            topic2.topicName = @"Unverifiable Line Items";
            [topicArray addObject:topic2];
            [cxSubCategory setTopiclist:[NSSet setWithArray:topicArray]];
            topicArray = nil;
        }
        [CXSubCatModelArray1 addObject:cxSubCategory];
    }
    CX_cat7.subCategorylist = [NSSet setWithArray:CXSubCatModelArray1];
    [CXSubCatModelArray1 removeAllObjects];
    return @[CX_cat1,CX_cat2,CX_cat3,CX_cat4,CX_cat5,CX_cat6,CX_cat7];
}

#pragma mark - FETCH SURVEY
-(MISurveyType*)fetchSurveyTypeWithName:(NSString*)name
{
    NSString *query = [NSString stringWithFormat:@"select * from SurveyType where name = '%@'",name];
    NSArray *arr =  [[MIDBManager getSharedInstance] fetchAllRecordsFromTable:query];
    return (arr.count>0)?arr[0]:nil;
}


//SAVE CURRENT SURVEY
-(void)saveCurrentSurvey
{
    for (int i=0; i< self.dealerList.count; i++)
    {
        MIDealerList* dealer = [self.dealerList objectAtIndex:i];
        [dealer encryptWithKey:MI_ENCRYPTION_KEY];
    }
    if (appDelegate.miFsr != nil)
    {
        [appDelegate.miFsr encryptWithKey:MI_ENCRYPTION_KEY];
    }
}


#pragma mark -  FSR
- (MIFSR*) currentFSRWithSSO:(NSString *)sso
{
    MIFSR* fsr = nil;
    NSArray* fsrList = [[MIDBManager getSharedInstance] fetchFSRDetail];
    if (fsrList != nil)
    {
        for (int i=0; i<fsrList.count;i++)
        {
            MIFSR* aFSR = [fsrList objectAtIndex:i];
            [aFSR decryptWithKey:MI_ENCRYPTION_KEY];
            if ([aFSR.sso isEqualToString:sso])
            {
                fsr = aFSR;
                break;
            }
        }
    }
    return fsr;
}

- (void) clearFSR
{
    [[MIDBManager getSharedInstance] deleteFSRDetail];
    [self saveCurrentSurvey];
}


#pragma makr - Dealer and Dealer Summery
/*
 ** Utility function to create Managed Dealer object from SOAP Response
 */
- (MIDealerList*) dealerFromSOAPCustomerData : (FSGMICustomerData*) customerData
{
    MIDealerList* aDealer = [[MIDealerList alloc] init];
    aDealer.customerName = customerData.CustomerName;
    aDealer.customerNo = customerData.CustomerNumber;
    aDealer.vbu = customerData.VBUName;
    aDealer.branchNo = customerData.BranchRegion;
    aDealer.branchDescription = customerData.BranchDescription;
    aDealer.statusCode = customerData.StatusCode;
    aDealer.masterNumber = customerData.MasterNumber;
    // Also add a Dealer Summary to Coredata
    MIDealerSummary* dealerSummary = [appDelegate.miSurveyUtil newDealerSummaryForDealer:aDealer];
    return aDealer;
}

/*
 ** Utility function to get Dealer object for transmission to SFDC
 */
- (MIDealerSummary*) newDealerSummaryForDealer:(MIDealerList*) dealer
{
    
    MIDealerSummary *aDealer;
    NSString *querySurveyType = [NSString stringWithFormat:@"select*from %@ where customerNumber == %@ AND branchNo == %@",TABLE_DEALERSUMMERY,dealer.customerNo,dealer.branchNo];
    [MIDBManager getSharedInstance].stateSelectedTable = 6;
    NSMutableArray *objDealerlist = [[MIDBManager getSharedInstance]fetchAllRecordsFromTable:querySurveyType];
    
    if (objDealerlist.count == 0)
    {
        // Not found create a new one
        aDealer = [[MIDealerSummary alloc] init];
        [aDealer setBranchDescription:dealer.branchDescription];
        [aDealer setBranchNo:dealer.branchNo];
        [aDealer setCustomerName:dealer.customerName];
        [aDealer setCustomerNumber:dealer.customerNo];
        [aDealer setVbu:dealer.vbu];
        [aDealer setMasterNumber:dealer.masterNumber];
        [aDealer setStatusCode:dealer.statusCode];
        [aDealer setIsValidated:@YES];
        [aDealer setAddedManually:@NO];
        [[MIDBManager getSharedInstance] insertDealerSummeryRecords:@[aDealer]];
        
    }
    else
    {
        aDealer = [[MIDBManager getSharedInstance] fetchDealerSummery][0];
    }
    return aDealer;
    
}


@end
