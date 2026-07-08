#import "RootViewController.h"
#import <dlfcn.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <sys/stat.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>

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
    
    // UI สไตล์ Custom Dark Theme
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
    subTitleLabel.text = @"เลือก .dylib / .framework เพื่อฉีดเข้าแอปตัวเอง";
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
        cell.detailTextLabel.text = @"ดึงไฟล์ .dylib หรือ .framework เข้ามาทำงานทันที";
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

#pragma mark - In-process FastPathSign Logic

- (BOOL)applyFastPathSignToDylib:(NSString *)dylibPath {
    NSData *fileData = [NSData dataWithContentsOfFile:dylibPath options:NSDataReadingMappedIfSafe error:nil];
    if (!fileData) return NO;
    
    NSMutableData *mutableData = [fileData mutableCopy];
    struct mach_header_64 *header = (struct mach_header_64 *)[mutableData mutableBytes];
    
    // เช็ก Magic Header ของไฟล์ arm64
    if (header->magic != MH_MAGIC_64) {
        NSLog(@"[Tester] ❌ โครงสร้างไฟล์ไม่ใช่ arm64 มาตรฐาน");
        return NO;
    }
    
    uint8_t *image_ptr = (uint8_t *)[mutableData mutableBytes];
    uint32_t cmd_offset = sizeof(struct mach_header_64);
    
    // ค้นหาตำแหน่งและขนาดโครงสร้างบล็อคลายเซ็นในไบนารีไฟล์
    for (uint32_t i = 0; i < header->ncmds; i++) {
        struct load_command *cmd = (struct load_command *)(image_ptr + cmd_offset);
        if (cmd->cmd == LC_CODE_SIGNATURE) {
            struct linkedit_data_command *cs_cmd = (struct linkedit_data_command *)cmd;
            
            // ล้างค่าบล็อคลายเซ็นที่เสียหายเดิมให้เป็นศูนย์ (Zero-out technique)
            // บังคับให้ระบบมองผ่าน และปล่อยให้ TrollStore/CoreTrust จัดระเบียบการโหลดหน่วยความจำเอง
            memset(image_ptr + cs_cmd->dataoff, 0, cs_cmd->datasize);
            NSLog(@"[Tester] 🟢 ล้างและ Patch ลายเซ็นใหม่สำเร็จ");
            
            // บันทึกไฟล์ที่แก้สำเร็จแล้วทับลงตำแหน่ง Sandbox ของเรา
            return [mutableData writeToFile:dylibPath atomically:YES];
        }
        cmd_offset += cmd->cmdsize;
    }
    return NO;
}

#pragma mark - Core Injection Logic

- (void)injectDylibWithPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // หันมาใช้โฟลเดอร์ Documents ภายใน Sandbox แอปเพื่อสิทธิ์ขาดในการเขียนและแก้ไขโครงสร้างไบนารี
    NSString *docsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *finalPathToInject = [docsDirectory stringByAppendingPathComponent:[path lastPathComponent]];
    
    if ([fileManager fileExistsAtPath:finalPathToInject]) {
        [fileManager removeItemAtPath:finalPathToInject error:nil];
    }
    
    if (![fileManager copyItemAtPath:path toPath:finalPathToInject error:nil]) {
        NSLog(@"[Tester] ❌ ไม่สามารถย้ายไฟล์เข้าโฟลเดอร์แอปได้");
    }
    
    // เรียกฟังก์ชัน Patch ลายเซ็นให้เรียบร้อยก่อนเรียกคำสั่งโหลดรัน
    [self applyFastPathSignToDylib:finalPathToInject];
    
    // ให้สิทธิ์สากลในการเปิดอ่านและรันโปรแกรมกับตัวไฟล์ (chmod 755)
    chmod([finalPathToInject UTF8String], 0755);

    // ฉีดไฟล์เข้าสู่แอปตัวเอง (Process เดียวกัน) ทันที
    void *handle = dlopen([finalPathToInject UTF8String], RTLD_NOW);
    
    if (handle) {
        if (![self.historyItems containsObject:path]) {
            [self.historyItems insertObject:path atIndex:0];
            [self.tableView reloadData];
        }
        [self showAlertWithTitle:@"SUCCESS 🟢" message:[NSString stringWithFormat:@"ฉีดเข้าแอปตัวเองสำเร็จ:\n%@", [path lastPathComponent]]];
    } else {
        const char *dlErrorStr = dlerror();
        NSString *errorMsg = [NSString stringWithFormat:@"โหลดล้มเหลว บั๊ก: %s", dlErrorStr];
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
