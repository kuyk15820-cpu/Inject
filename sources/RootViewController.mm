#import "RootViewController.h"
#import <dlfcn.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <sys/stat.h>    // สำหรับใช้คำสั่ง chmod ปรับสิทธิ์ไฟล์

@interface RootViewController () <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *historyItems; // เก็บลายชื่อไฟล์ที่เคยฉีดไว้เทส

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
    
    // ตั้งค่าพื้นหลังดาร์กโทน สไตล์ Liquid Glass Dark Theme
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
    // ส่วนหัวของแอปสไตล์ Dark Mode
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
    // สร้างตารางในสไตล์ Dark Custom Tables
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
    return 2; // Section 0: ปุ่มเลือกไฟล์หลัก, Section 1: ประวัติการฉีดทดสอบ
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
        
        // Custom Selection Color (เวลาคลิกให้เป็นสีเทาเข้ม)
        UIView *bgColorView = [[UIView alloc] init];
        bgColorView.backgroundColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.22 alpha:1.0];
        [cell setSelectedBackgroundView:bgColorView];
    }
    
    if (indexPath.section == 0) {
        cell.textLabel.text = @"➕ เลือกและฉีดไฟล์ใหม่ (File Picker)";
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        cell.textLabel.textColor = [UIColor colorWithRed:0.22 green:0.65 blue:1.00 alpha:1.0]; // สีฟ้าเรืองแสง
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
        // เรียกตัวเลือกไฟล์ระบบ
        [self openDocumentPicker];
    } else {
        // สั่งฉีดซ้ำจากประวัติ
        NSString *savedPath = self.historyItems[indexPath.row];
        [self injectDylibWithPath:savedPath];
    }
}

#pragma mark - Document Picker Logic

- (void)openDocumentPicker {
    // ใช้ UTType String แบบดั้งเดิม เพื่อให้คอมไพล์ผ่าน Theos SDK ได้ทุกเวอร์ชัน
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

#pragma mark - Core Injection Logic (วิธีที่ 2: โหลดผ่านโฟลเดอร์ Documents)

- (void)injectDylibWithPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // 1. หาตำแหน่งโฟลเดอร์ Documents ของตัวแอปเราเอง (จุดนี้แอปเข้าถึงได้ 100% ไม่ติดสิทธิ์บล็อก)
    NSString *docsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *finalPathToInject = [docsDirectory stringByAppendingPathComponent:[path lastPathComponent]];
    
    // 2. ลบไฟล์เก่าออกก่อน (ถ้ามีชื่อซ้ำ) เพื่อให้อัปเดตไฟล์ใหม่ได้ตลอดเวลา
    if ([fileManager fileExistsAtPath:finalPathToInject]) {
        [fileManager removeItemAtPath:finalPathToInject error:nil];
    }
    
    // 3. คัดลอกไฟล์ที่เลือกเข้ามาไว้ในโฟลเดอร์แอปตัวเอง
    NSError *error = nil;
    if (![fileManager copyItemAtPath:path toPath:finalPathToInject error:&error]) {
        NSLog(@"[Tester] คัดลอกไฟล์ล้มเหลว: %@", error.localizedDescription);
    }
    
    // 4. เปลี่ยนสิทธิ์ไฟล์ดิลลิบให้อ่านและรันได้เต็มที่ (Chmod 755)
    chmod([finalPathToInject UTF8String], 0755);

    // 5. สั่งฉีด (Load) ไฟล์เข้า Process ตัวเองทันที
    void *handle = dlopen([finalPathToInject UTF8String], RTLD_NOW);
    
    if (handle) {
        // เพิ่มเข้าไปในประวัติถ้ายังไม่มี
        if (![self.historyItems containsObject:path]) {
            [self.historyItems insertObject:path atIndex:0];
            [self.tableView reloadData];
        }
        [self showAlertWithTitle:@"SUCCESS 🟢" message:[NSString stringWithFormat:@"ฉีดสำเร็จ: %@", [path lastPathComponent]]];
    } else {
        const char *dlErrorStr = dlerror();
        NSString *errorMsg = [NSString stringWithFormat:@"บั๊ก: %s", dlErrorStr];
        [self showAlertWithTitle:@"ERROR 🔴" message:errorMsg];
    }
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    // แต่งปุ่มตกลงในสไตล์เข้าคู่กัน
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"ตกลง" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
