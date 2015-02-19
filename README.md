# Autocomplete+ clang POC for Objective C

This is an experimental clang provider for Atom's autocomplete-plus. This has a few assumptions for objective c.

## Clang notes

`clang` supports a command line arg named `-code-completion-at` where you can pass a row and column, and get contextual completions back.

```bash
clang -fsyntax-only -xobjective-c -Xclang -code-completion-at=MyFile.m:20:2 -include-pch test.pch -I. MyFile.m
```

And it will return a bunch of lines of potential completions:

```
COMPLETION: abortEditing : [#BOOL#]abortEditing
COMPLETION: acceptsFirstMouse: : [#BOOL#]acceptsFirstMouse:<#(NSEvent *)#>
COMPLETION: acceptsFirstResponder : [#BOOL#]acceptsFirstResponder
COMPLETION: acceptsTouchEvents : [#BOOL#]acceptsTouchEvents
COMPLETION: accessibilityActionDescription: : [#NSString *#]accessibilityActionDescription:<#(NSString *)#>
COMPLETION: accessibilityActionNames : [#NSArray *#]accessibilityActionNames
COMPLETION: accessibilityArrayAttributeCount: : [#NSUInteger#]accessibilityArrayAttributeCount:<#(NSString *)#>
COMPLETION: accessibilityArrayAttributeValues:index:maxCount: : [#NSArray *#]accessibilityArrayAttributeValues:<#(NSString *)#> index:<#(NSUInteger)#> maxCount:<#(NSUInteger)#>
```

Clang returns _all_ potential completions for a symbol. Consider the following code:

```objc
@implementation SomeButton

- (NSString*)myFunc:(NSPoint)aPoint {
  [self some|]; // << pretend our cursor is at the pipe; position [4, 13]
}

@end
```

Clang doesnt do context or filtering. So, while the cursor is at `[4, 13]`, to get all the completions for `self` we will need to pass clang position `[4, 8]`, then filter the entire list by the prefix: `some` in this case.

If it does not have a valid symbol to provide context, it will return _all_ available global symbols.

### Pre compiled headers

For this provider to work reasonably well, you currently need to make your own pre compiled header and put it at `test.pch`. For an objective c app, save a file with the following:

```objc
#import <Cocoa/Cocoa.h>
#import <SystemConfiguration/SystemConfiguration.h>
```

And run

```
clang -xobjective-c-header -Xclang -emit-pch -o test.pch -I. myfile.h
```
