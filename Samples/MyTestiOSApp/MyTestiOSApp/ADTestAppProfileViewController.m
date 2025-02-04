// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "ADTestAppProfileViewController.h"
#import "ADTestAppSettings.h"

@interface ADTestAppProfileViewController ()

@end

@implementation ADTestAppProfileViewController
{
    UITableView* _profileTable;
}

+ (ADTestAppProfileViewController*)sharedProfileViewController
{
    static ADTestAppProfileViewController* s_profileViewController = nil;
    static dispatch_once_t s_once;
    
    dispatch_once(&s_once, ^{
        s_profileViewController = [[ADTestAppProfileViewController alloc] init];
    });
    
    return s_profileViewController;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.navigationController.navigationBarHidden = NO;
    self.navigationItem.hidesBackButton = NO;
    self.navigationItem.title = @"Select Application Profile";
    
    UIView* rootView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [rootView setAutoresizesSubviews:YES];
    [rootView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    _profileTable = [[UITableView alloc] initWithFrame:rootView.frame];
    [_profileTable setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [_profileTable setDataSource:self];
    
    NSString* currentProfile = [ADTestAppSettings currentProfileTitle];
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[[ADTestAppSettings profileTitles] indexOfObject:currentProfile] inSection:0];
    [_profileTable selectRowAtIndexPath:indexPath
                               animated:NO
                         scrollPosition:UITableViewScrollPositionNone];
    [_profileTable setDelegate:self];
    [rootView addSubview:_profileTable];
    
    self.view = rootView;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString* rowTitle = [[ADTestAppSettings profileTitles] objectAtIndex:indexPath.row];
    NSDictionary* rowDict = [[ADTestAppSettings profiles] objectForKey:rowTitle];
    [[ADTestAppSettings settings] setFromDictionary:rowDict];
    [[NSUserDefaults standardUserDefaults] setObject:rowTitle forKey:@"CurrentProfile"];
    [self.navigationController popViewControllerAnimated:YES];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[ADTestAppSettings profileTitles] count];
}

// Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
// Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"profileCell"];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"profileCell"];
    }

    NSString* title = [[ADTestAppSettings profileTitles] objectAtIndex:indexPath.row];
    [[cell textLabel] setText:title];
    
    return cell;
}

@end
