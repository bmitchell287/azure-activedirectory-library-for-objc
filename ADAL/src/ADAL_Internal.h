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

//iOS does not support resources in client libraries. Hence putting the
//version in static define until we identify a better place:
#define ADAL_VER_HIGH       2
#define ADAL_VER_LOW        2
#define ADAL_VER_PATCH      1

#define STR_ADAL_VER_HIGH   "2"
#define STR_ADAL_VER_LOW    "2"
#define STR_ADAL_VER_PATCH  "1"

// Framework versions only support high and low for the double value, sadly.
#define ADAL_VERSION_NUMBER 2.2

#define ADAL_VERSION_STRING     STR_ADAL_VER_HIGH "." STR_ADAL_VER_LOW "." STR_ADAL_VER_PATCH
#define ADAL_VERSION_NSSTRING   @"" STR_ADAL_VER_HIGH "." STR_ADAL_VER_LOW "." STR_ADAL_VER_PATCH

#define ADAL_VERSION_(high, low, patch) adalVersion_ ## high ## _ ## low ## _ ## patch

// This is specially crafted so the name of the variable matches the full ADAL version
#define ADAL_VERSION_VAR ADAL_VERSION_(2, 2, 1)

#import "ADLogger+Internal.h"
#import "ADErrorCodes.h"
#import "ADAuthenticationError+Internal.h"
#import "ADAuthenticationResult+Internal.h"
#import "NSString+ADHelperMethods.h"

@class ADAuthenticationResult;

/*! The completion block declaration. */
typedef void(^ADAuthenticationCallback)(ADAuthenticationResult* result);


#if TARGET_OS_IPHONE
//iOS:
#   include <UIKit/UIKit.h>
typedef UIWebView WebViewType;
#else
//OS X:
#   include <WebKit/WebKit.h>
typedef WebView   WebViewType;
#endif

#import "ADAuthenticationRequest.h"

//Helper macro to initialize a variable named __where string with place in file details:
#define WHERE \
NSString* __where = [NSString stringWithFormat:@"In function: %s, file line #%u", __PRETTY_FUNCTION__, __LINE__]

#define ADAL_VERSION \
NSString* __adalVersion = [NSString stringWithFormat:@"ADAL API call [Version - %@]",[ADLogger getAdalVersion]]

//General macro for throwing exception named NSInvalidArgumentException
#define THROW_ON_CONDITION_ARGUMENT(CONDITION, ARG) \
{ \
    if (CONDITION) \
    { \
        WHERE; \
        AD_LOG_ERROR(@"InvalidArgumentException: " #ARG, AD_ERROR_DEVELOPER_INVALID_ARGUMENT, nil, __where); \
        @throw [NSException exceptionWithName: NSInvalidArgumentException \
                                       reason:@"Please provide a valid '" #ARG "' parameter." \
                                     userInfo:nil];  \
    } \
}

// Checks a selector NSString argument to a method for being null or empty. Throws NSException with name
// NSInvalidArgumentException if the argument is invalid:
#define THROW_ON_NIL_EMPTY_ARGUMENT(ARG) THROW_ON_CONDITION_ARGUMENT([NSString adIsStringNilOrBlank:ARG], ARG);

//Checks a selector argument for being null. Throws NSException with name NSInvalidArgumentException if
//the argument is invalid
#define THROW_ON_NIL_ARGUMENT(ARG) THROW_ON_CONDITION_ARGUMENT(!(ARG), ARG);

//Added to methods that are not implemented yet:
#define NOT_IMPLEMENTED @throw [NSException exceptionWithName:@"NotImplementedException" reason:@"Not Implemented" userInfo:nil];

//Fills the 'error' parameter
#define FILL_PARAMETER_ERROR(ARG) \
if (error) \
{ \
*error = [ADAuthenticationError errorFromArgument:ARG \
argumentName:@#ARG correlationId:nil]; \
}

#define STRING_NIL_OR_EMPTY_CONDITION(ARG) [NSString adIsStringNilOrBlank:ARG]
#define NIL_CONDITION(ARG) (!ARG)

#define RETURN_ON_INVALID_ARGUMENT(CONDITION, ARG, RET) \
{ \
    if (CONDITION) \
    { \
        WHERE; \
        AD_LOG_ERROR(@"InvalidArgumentError: " #ARG, AD_ERROR_DEVELOPER_INVALID_ARGUMENT, nil, __where); \
        FILL_PARAMETER_ERROR(ARG); \
        return RET; \
    } \
}

//Used for methods that have (ADAuthenticationError * __autoreleasing *) error parameter to be
//used for error conditions. The macro checks if ARG is nil or an empty string, sets the error and returns nil.
#define RETURN_NIL_ON_NIL_EMPTY_ARGUMENT(ARG) RETURN_ON_INVALID_ARGUMENT(STRING_NIL_OR_EMPTY_CONDITION(ARG), ARG, nil)

//Used for methods that have (ADAuthenticationError * __autoreleasing *) error parameter to be
//used for error conditions, but return no value (void). The macro checks if ARG is nil or an empty string,
//sets the error and returns.
#define RETURN_ON_NIL_EMPTY_ARGUMENT(ARG) RETURN_ON_INVALID_ARGUMENT(STRING_NIL_OR_EMPTY_CONDITION(ARG), ARG, )

//Same as the macros above, but used for non-string parameters for nil checking.
#define RETURN_NIL_ON_NIL_ARGUMENT(ARG) RETURN_ON_INVALID_ARGUMENT(NIL_CONDITION(ARG), ARG, nil)

//Same as the macros above, but returns BOOL (NO), instead of nil.
#define RETURN_NO_ON_NIL_ARGUMENT(ARG) RETURN_ON_INVALID_ARGUMENT(NIL_CONDITION(ARG), ARG, NO)

//Same as the macros above, but used for non-string parameters for nil checking.
#define RETURN_ON_NIL_ARGUMENT(ARG) RETURN_ON_INVALID_ARGUMENT(NIL_CONDITION(ARG), ARG, )

//Converts constant string literal to NSString. To be used in macros, e.g. TO_NSSTRING(__FILE__).
//Can be used only inside another macro.
#define TO_NSSTRING(x) @"" x

//Logs public function call:
#define API_ENTRY \
{ \
WHERE; \
ADAL_VERSION; \
AD_LOG_VERBOSE(__adalVersion, nil, __where); \
}

#if __has_feature(objc_arc)
#define __WEAK __weak
#define SAFE_ARC_RETAIN(x)
#define SAFE_ARC_RELEASE(x)
#define SAFE_ARC_AUTORELEASE(x)
#define SAFE_ARC_SUPER_DEALLOC()

#else // ! __has_feature(objc_arc)
#define __WEAK
#define SAFE_ARC_RETAIN(x) ([(x) retain])
#define SAFE_ARC_RELEASE(x) { [(x) release]; }
#define SAFE_ARC_AUTORELEASE(x) ([(x) autorelease])
#define SAFE_ARC_SUPER_DEALLOC() ([super dealloc])
#endif
