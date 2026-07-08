#import "RootViewController.h"
#import <dlfcn.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <spawn.h>       // ➕ เพิ่มสิทธิ์รันคำสั่งเบื้องหลัง
#import <sys/wait.h>    // ➕ เพิ่มตัวจัดการจบกระบวนการรัน
#import <sys/stat.h>    // ➕ เพิ่มระบบเปลี่ยนสิทธิ์ไฟล์ (chmod)

@interface RootViewController () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *historyItems; 

@end

@implementation RootViewController

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait; 
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.08 alpha:1.0];
    
    if (self.navigationController) {
        self.navigationController.navigationBarHidden = YES;
    }
    
    self.historyItems = [[NSMutableArray alloc] init];
    
    [self setupHeaderView];
    [self setupTableView];
}

#pragma mark - UI Setup

- (void)setupHeaderView {
    UIView *headerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 140)];
    headerContainer.backgroundColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.12 alpha:1.0];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, self.view.bounds.size.width - 40, 30)];
    titleLabel.text = @"TrollStore Injector";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    [headerContainer addSubview:titleLabel];
    
    UILabel *subTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 95, self.view.bounds.size.width - 40, 20)];
    subTitleLabel.text = @"เลือกไฟล์ .dylib หรือ .framework เพื่อทดสอบ";
    subTitleLabel.textColor = [UIColor lightGrayColor];
    subTitleLabel.font = [UIFont systemFontOfSize:14];
    [headerContainer addSubview:subTitleLabel];
    
    [self.view addSubview:headerContainer];
}

- (void)setupTableView {
    CGFloat topOffset = 140.0;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, topOffset, self.view.bounds.size.width, self.view.bounds.size.height - topOffset) style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [UIColor colorWithRed:0.18 green:0.18 blue:0.20 alpha:1.0];
    
    [self.view addSubview:self.tableView];
}

#pragma mark - UITableView DataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    } else {
        return self.historyItems.count == 0 ? 1 : self.historyItems.count;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 55.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"CustomDarkCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        
        UIView *bgColorView = [[UIView alloc] init];
        bgColorView.backgroundColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.22 alpha:1.0];
        [cell setSelectedBackgroundView:bgColorView];
    }
    
    if (indexPath.section == 0) {
        cell.textLabel.text = @"➕ เลือกและฉีดไฟล์ใหม่ (File Picker)";
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        cell.textLabel.textColor = [UIColor colorWithRed:0.22 green:0.65 blue:1.00 alpha:1.0];
        cell.detailTextLabel.text = @"รองรับไฟล์ .dylib และ .framework จากแอปไฟล์";
    } else {
        if (self.historyItems.count == 0) {
            cell.textLabel.text = @"ยังไม่มีประวัติการเทสไฟล์";
            cell.textLabel.textColor = [UIColor darkGrayColor];
            cell.detailTextLabel.text = @"";
            cell.userInteractionEnabled = NO;
        } else {
            cell.userInteractionEnabled = YES;
            NSString *fullPath = self.historyItems[indexPath.row];
            cell.textLabel.text = [fullPath lastPathComponent];
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.detailTextLabel.text = @"คลิกเพื่อฉีดซ้ำอีกครั้ง";
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        [self openDocumentPicker];
    } else {
        NSString *savedPath = self.historyItems[indexPath.row];
        [self injectDylibWithPath:savedPath];
    }
}

#pragma mark - Document Picker Logic

- (void)openDocumentPicker {
    // แก้ไขเป็นแบบรองรับ Theos SDK ทุกเวอร์ชันเรียบร้อย
    NSArray *types = @[@"com.apple.dynamic-library", @"com.apple.framework", @"public.data"];
    
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:types inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *selectedFileURL = [urls firstObject];
    if (!selectedFileURL) return;
    
    BOOL startAccessing = [selectedFileURL startAccessingSecurityScopedResource];
    NSString *filePath = [selectedFileURL path];
    NSString *fileExtension = [[selectedFileURL pathExtension] lowercaseString];
    
    if ([fileExtension isEqualToString:@"dylib"]) {
        [self injectDylibWithPath:filePath];
    } else if ([fileExtension isEqualToString:@"framework"]) {
        NSString *binaryPath = [filePath stringByAppendingPathComponent:[[filePath lastPathComponent] stringByDeletingPathExtension]];
        [self injectDylibWithPath:binaryPath];
    }
    
    if (startAccessing) {
        [selectedFileURL stopAccessingSecurityScopedResource];
    }
}

#pragma mark - ➕ ฟังก์ชันสั่งรันออโต้เซ็น (ldid Engine)

- (BOOL)pseudoSignFileAtPath:(NSString *)filePath {
    // 1. วิ่งไปค้นหาไฟล์ ldid ของ opa334 ที่ใส่ไว้ในโปรเจกต์ (Resource Bundle)
    NSString *ldidPath = [[NSBundle mainBundle] pathForResource:@"ldid" ofType:@""];
    
    if (!ldidPath || ![[NSFileManager defaultManager] fileExistsAtPath:ldidPath]) {
        NSLog(@"[Tester] ❌ ไม่พบเครื่องมือ ldid ใน App Resource");
        return NO; 
    }
    
    // 2. ให้สิทธิ์ระบบกับไฟล์ ldid ให้สามารถรันได้ (Chmod 755)
    chmod([ldidPath UTF8String], 0755);

    pid_t pid;
    // 3. ใช้คำสั่งยัด Fake-Sign: ldid -S [ตำแหน่งดิลลิบ]
    const char *args[] = {[ldidPath UTF8String], "-S", [filePath UTF8String], NULL};
    extern char **environ;
    
    int status = posix_spawn(&pid, [ldidPath UTF8String], NULL, NULL, (char* const*)args, environ);
    if (status == 0) {
        int waitStatus;
        waitpid(pid, &waitStatus, 0);
        NSLog(@"[Tester] 🟢 ออโต้เซ็นโค้ดเรียบร้อยแล้ว!");
        return YES;
    }
    
    return NO;
}

#pragma mark - Core Injection Logic

- (void)injectDylibWithPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *finalPathToInject = path;
    
    // 1. คัดลอกไฟล์มาไว้ใน Sandbox (โฟลเดอร์ tmp) ของตัวเองก่อนเพื่อแก้ปัญหาติดสิทธิ์อ่าน/เขียน
    NSString *tmpDirectory = NSTemporaryDirectory();
    NSString *tempDylibPath = [tmpDirectory stringByAppendingPathComponent:[path lastPathComponent]];
    
    if ([fileManager fileExistsAtPath:tempDylibPath]) {
        [fileManager removeItemAtPath:tempDylibPath error:nil];
    }
    
    if ([fileManager copyItemAtPath:path toPath:tempDylibPath error:nil]) {
        finalPathToInject = tempDylibPath;
    }

    // 2. 🔥 สั่งออโต้เซ็นแก้อาการ ลายเซ็นไม่ถูกต้อง (Code Signature Invalid)
    [self pseudoSignFileAtPath:finalPathToInject];
    
    // 3. ปรับสิทธิ์ไฟล์ดิลลิบให้แอปเปิดใช้ได้เต็มที่
    chmod([finalPathToInject UTF8String], 0755);

    // 4. สั่งฉีดรันเข้าตัวแอป
    void *handle = dlopen([finalPathToInject UTF8String], RTLD_NOW);
    
    if (handle) {
        if (![self.historyItems containsObject:path]) {
            [self.historyItems insertObject:path atIndex:0];
            [self.tableView reloadData];
        }
        [self showAlertWithTitle:@"SUCCESS 🟢" message:[NSString stringWithFormat:@"ฉีดสำเร็จ: %@", [path lastPathComponent]]];
    } else {
        const char *error = dlerror();
        NSString *errorMsg = [NSString stringWithFormat:@"บั๊ก: %s", error];
        [self showAlertWithTitle:@"ERROR 🔴" message:errorMsg];
    }
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"ตกลง" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
