#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ============================================================
// DylibLab — минимальный шаблон менюшки для теста стенда.
// Что делает: через 1 сек после dlopen показывает красный
// UIWindow с кнопкой, которую можно таскать. Так проверяется
// что dlopen -> constructor -> UIWindow цепочка жива.
// ============================================================

static UIWindow *gWin = nil;

static void showMenu(void) {
    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
    }
    if (!scene) { NSLog(@"[MenuTemplate] нет UIWindowScene"); return; }

    UIWindow *win = [[UIWindow alloc] initWithWindowScene:scene];
    win.frame = [UIScreen mainScreen].bounds;
    win.windowLevel = UIWindowLevelAlert + 1;
    win.backgroundColor = [UIColor clearColor];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(80, 80, 220, 60);
    [btn setTitle:@"MENU v1 — TAP" forState:UIControlStateNormal];
    btn.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.92];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.layer.cornerRadius = 12;
    [btn addTarget:btn action:@selector(removeFromSuperview) forControlEvents:UIControlEventTouchUpInside];
    [win addSubview:btn];

    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(80, 150, 320, 28)];
    hint.text = @"Template menu: окно живо ✓";
    hint.textColor = [UIColor whiteColor];
    hint.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    hint.font = [UIFont systemFontOfSize:13];
    hint.textAlignment = NSTextAlignmentCenter;
    [win addSubview:hint];

    gWin = win;
    [win makeKeyAndVisible];
    NSLog(@"[MenuTemplate] окно показано ✓");
}

// Constructor — вызывается автоматически при dlopen
__attribute__((constructor))
static void menu_init(void) {
    NSLog(@"[MenuTemplate] constructor вызван — dylib в памяти");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        showMenu();
    });
}
