//
//  HSUBaseViewController.m
//  Tweet4China
//
//  Created by Jason Hsu on 3/3/13.
//  Copyright (c) 2013 Jason Hsu <support@tuoxie.me>. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "HSUBaseViewController.h"
#import "HSUTexturedView.h"
#import "HSUStatusCell.h"
#import "HSURefreshControl.h"
#import "HSULoadMoreCell.h"
#import "HSUTabController.h"
#import "HSUComposeViewController.h"
#import "HSUStatusViewController.h"
#import "HSUNavigationBarLight.h"
#import "HSUNormalTitleCell.h"
#import "HSUPersonListViewController.h"
#import "HSUFollowersDataSource.h"
#import "HSUFollowingDataSource.h"
#import "HSUPersonCell.h"
#import "HSUChatStatusCell.h"
#import "HSUDefaultStatusCell.h"
#import "HSUDraftCell.h"
#import "HSUDraftsCell.h"
#import "HSUConversationCell.h"
#import "HSUMessageCell.h"

@interface HSUBaseViewController ()

@property (nonatomic, assign) float defaultKeyboardHeight;

@end

@implementation HSUBaseViewController

#pragma mark - Liftstyle
- (void)dealloc
{
    notification_remove_observer(self);
}

- (id)init
{
    self = [super init];
    if (self) {
        self.dataSourceClass = [HSUBaseDataSource class];
        self.useRefreshControl = YES;
    }
    return self;
}

- (id)initWithDataSource:(HSUBaseDataSource *)dataSource
{
    self = [self init];
    if (self) {
        self.dataSource = dataSource;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    notification_add_observer(UIKeyboardWillChangeFrameNotification, self, @selector(keyboardFrameChanged:));
    notification_add_observer(UIKeyboardWillHideNotification, self, @selector(keyboardWillHide:));
    notification_add_observer(UIKeyboardWillShowNotification, self, @selector(keyboardWillShow:));
    
    if (!self.dataSource) {
        self.dataSource = [self.dataSourceClass dataSourceWithDelegate:self useCache:YES];
    }
    self.dataSource.delegate = self;
    
    for (HSUTableCellData *cellData in self.dataSource.allData) {
        cellData.renderData[@"attributed_label_delegate"] = self;
    }
    
    UITableView *tableView;
    if (self.tableView) {
        tableView = self.tableView;
    } else {
        tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        [self.view addSubview:tableView];
        self.tableView = tableView;
    }
    // todo: rework
    [tableView registerClass:[HSUDefaultStatusCell class] forCellReuseIdentifier:kDataType_DefaultStatus];
    [tableView registerClass:[HSUChatStatusCell class] forCellReuseIdentifier:kDataType_ChatStatus];
    [tableView registerClass:[HSUPersonCell class] forCellReuseIdentifier:kDataType_Person];
    [tableView registerClass:[HSULoadMoreCell class] forCellReuseIdentifier:kDataType_LoadMore];
    [tableView registerClass:[HSUNormalTitleCell class] forCellReuseIdentifier:kDataType_NormalTitle];
    [tableView registerClass:[HSUDraftCell class] forCellReuseIdentifier:kDataType_Draft];
    [tableView registerClass:[HSUDraftsCell class] forCellReuseIdentifier:kDataType_Drafts];
    [tableView registerClass:[HSUConversationCell class] forCellReuseIdentifier:kDataType_Conversation];
    [tableView registerClass:[HSUMessageCell class] forCellReuseIdentifier:kDataType_Message];
    tableView.dataSource = self.dataSource;
    tableView.delegate = self;
    tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    tableView.backgroundColor = kClearColor;
    tableView.backgroundView = nil;
    tableView.separatorColor = rgb(206, 206, 206);
    
    if (self.useRefreshControl) {
        HSURefreshControl *refreshControl = [[HSURefreshControl alloc] init];
        [refreshControl addTarget:self.dataSource action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
        [tableView addSubview:refreshControl];
        self.refreshControl = refreshControl;
    }
    
    if (!self.hideRightButtons) {
        self.navigationItem.rightBarButtonItems = [self _createRightBarButtonItems];
    }
    if (!self.hideBackButton) {
        if ([self.navigationController.viewControllers objectAtIndex:0] != self) {
            self.navigationItem.leftBarButtonItem = [self _createBackButton];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"bg_texture"]];
    self.tableView.frame = self.view.bounds;
    
    NSIndexPath *selection = [self.tableView indexPathForSelectedRow];
	if (selection)
		[self.tableView deselectRowAtIndexPath:selection animated:YES];
    notification_post(kNotification_HSUStatusCell_OtherCellSwiped);
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.viewDidAppearCount ++;
}

- (void)keyboardFrameChanged:(NSNotification *)notification
{
    NSValue* keyboardFrame = [notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey];
    self.keyboardHeight = keyboardFrame.CGRectValue.size.height;
    self.defaultKeyboardHeight = self.keyboardHeight;
    [self.view setNeedsLayout];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    self.keyboardHeight = 0;
    [self.view setNeedsDisplay];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    self.keyboardHeight = self.defaultKeyboardHeight;
    [self.view setNeedsDisplay];
    
//    [self.tableView setContentOffset:ccp(0, self.tableView.contentSize.height) animated:YES];
}

#pragma mark - TableView
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    HSUTableCellData *data = [self.dataSource dataAtIndexPath:indexPath];
    Class cellClass = [self cellClassForDataType:data.dataType];
    return [cellClass heightForData:data];
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    HSUTableCellData *data = [self.dataSource dataAtIndex:indexPath.row];
    if ([data.dataType isEqualToString:kDataType_DefaultStatus]) {
        if ([data.renderData[@"mode"] isEqualToString:@"action"]) {
            return NO;
        }
        return YES;
    }
    if ([data.dataType isEqualToString:kDataType_LoadMore]) {
        return NO;
    }
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    HSUTableCellData *data = [self.dataSource dataAtIndexPath:indexPath];
    if ([data.dataType isEqualToString:kDataType_LoadMore]) {
        [self.dataSource loadMore];
    }
}

- (Class)cellClassForDataType:(NSString *)dataType
{
    return NSClassFromString([NSString stringWithFormat:@"HSU%@Cell", dataType]);
}

- (void)dataSource:(HSUBaseDataSource *)dataSource didFinishRefreshWithError:(NSError *)error
{
    [self.refreshControl endRefreshing];
    if (error) {
        NSLog(@"%@", error);
    } else {
        for (HSUTableCellData *cellData in self.dataSource.allData) {
            cellData.renderData[@"attributed_label_delegate"] = self;
        }
        
        [self.tableView reloadData];
    }

    [((HSUTabController *)self.tabBarController) hideUnreadIndicatorOnTabBarItem:self.navigationController.tabBarItem];
}

- (void)dataSource:(HSUBaseDataSource *)dataSource didFinishLoadMoreWithError:(NSError *)error
{
    if (error) {
        NSLog(@"%@", error);
    } else {
        [self.tableView reloadData];
        [self.refreshControl endRefreshing];
    }
}

- (void)dataSourceDidFindUnread:(HSUBaseDataSource *)dataSource
{
    [((HSUTabController *)self.tabBarController) showUnreadIndicatorOnTabBarItem:self.navigationController.tabBarItem];
}

- (void)preprocessDataSourceForRender:(HSUBaseDataSource *)dataSource
{
}

#pragma mark - base view controller's methods
- (NSArray *)_createRightBarButtonItems
{
    // Search BarButtonItem
    UIButton *searchButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [searchButton setImage:[UIImage imageNamed:@"ic_title_search"] forState:UIControlStateNormal];
    [searchButton sizeToFit];
    searchButton.width *= 2.1;
    searchButton.showsTouchWhenHighlighted = YES;
    UIBarButtonItem *searchBarButton = [[UIBarButtonItem alloc] initWithCustomView:searchButton];
    
    [searchButton setTapTarget:self action:@selector(_searchButtonTouched)];
    
    // Compose BarButtonItem
    UIButton *composeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [composeButton setImage:[UIImage imageNamed:@"ic_title_tweet"] forState:UIControlStateNormal];
    [composeButton sizeToFit];
    composeButton.width *= 1.42;
    composeButton.showsTouchWhenHighlighted = YES;
    [composeButton setTapTarget:self action:@selector(_composeButtonTouched)];
    
    UIBarButtonItem *composeBarButton = [[UIBarButtonItem alloc] initWithCustomView:composeButton];
    
    return @[composeBarButton, searchBarButton];
}

- (UIBarButtonItem *)_createBackButton
{
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [backButton setImage:[UIImage imageNamed:@"icn_nav_bar_back"] forState:UIControlStateNormal];
    [backButton sizeToFit];
    backButton.width *= 1.6;
    backButton.showsTouchWhenHighlighted = YES;
    [backButton setTapTarget:self action:@selector(backButtonTouched)];
    
    return [[UIBarButtonItem alloc] initWithCustomView:backButton];
}

- (void)backButtonTouched
{
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Actions
- (void)_composeButtonTouched
{
    HSUComposeViewController *composeVC = [[HSUComposeViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithNavigationBarClass:[HSUNavigationBarLight class] toolbarClass:nil];
    nav.viewControllers = @[composeVC];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)_searchButtonTouched
{
    L(@"search button touched");
}

- (void)presentModelClass:(Class)modelClass
{
    UINavigationController *nav = DEF_NavitationController_Light;
    UIViewController *vc = [[modelClass alloc] init];
    nav.viewControllers = @[vc];
    [self presentViewController:nav animated:YES completion:nil];
}

@end
