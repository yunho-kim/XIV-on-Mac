//
//  LaunchController.swift
//  XIV on Mac
//
//  Created by Marc-Aurel Zent on 02.02.22.
//

import Cocoa
import XIVLauncher

class LaunchController: NSViewController {
    var loginSheetWinController: NSWindowController?
    var installerWinController: NSWindowController?
    var patchWinController: NSWindowController?
    var repairWinController: NSWindowController?
    var patchController: PatchController?
    var repairController: RepairController?
    var newsTable: FrontierTableView!
    var topicsTable: FrontierTableView!
    var otp: OTP?

    @IBOutlet private var loginButton: NSButton!
    @IBOutlet var userField: NSTextField!
    @IBOutlet private var userMenu: NSMenu!
    @IBOutlet private var passwdField: NSTextField!
    @IBOutlet private var captchaImageView: NSImageView!
    @IBOutlet private var captchaField: NSTextField!
    @IBOutlet private var captchaRefreshButton: NSButton!
    @IBOutlet private var captchaStatusLabel: NSTextField!
    @IBOutlet var otpField: NSTextField!
    @IBOutlet var otpCheck: NSButton!
    @IBOutlet var autoLoginCheck: NSButton!
    @IBOutlet private var scrollView: AnimatingScrollView!
    @IBOutlet private var newsView: NSScrollView!
    @IBOutlet private var topicsView: NSScrollView!
    @IBOutlet var discloseButton: NSButton!
    @IBOutlet private var touchBarLoginButton: NSButtonTouchBarItem!
    @IBOutlet var leftButton: NSButton!
    @IBOutlet var rightButton: NSButton!

    private var captchaReady = false
    private var captchaLoading = false
    private var captchaRequestID = UUID()
    private var koreanLoginInProgress = false
    private var koreanOtpPromptController: KoreanOtpPromptController?

    override func loadView() {
        super.loadView()
        update()
        NotificationCenter.default.addObserver(
            self, selector: #selector(installDone(_:)), name: .installDone,
            object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(showSideButtons(_:)), name: .bannerEnter,
            object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(hideSideButtons(_:)), name: .bannerLeft,
            object: nil)
        userMenu.minimumWidth = 264
        newsTable = FrontierTableView(
            icon: NSImage(
                systemSymbolName: "newspaper", accessibilityDescription: nil)!)
        topicsTable = FrontierTableView(
            icon: NSImage(
                systemSymbolName: "newspaper.fill",
                accessibilityDescription: nil)!)
        newsView.documentView = newsTable.tableView
        topicsView.documentView = topicsTable.tableView
        leftButton.wantsLayer = true
        rightButton.wantsLayer = true
        setSideButtonVisibility(to: false)
        captchaImageView.wantsLayer = true
        captchaImageView.layer?.backgroundColor = NSColor.textBackgroundColor
            .withAlphaComponent(0.85).cgColor
        captchaImageView.layer?.cornerRadius = 4
        updateKoreanLoginControls()
    }

    @objc func installDone(_ notif: Notification) {
        DispatchQueue.main.async {
            self.loadKoreanCaptcha(force: true)
        }
    }

    @objc func hideSideButtons(_ notif: Notification) {
        setSideButtonVisibility(to: false)
    }

    @objc func showSideButtons(_ notif: Notification) {
        setSideButtonVisibility(to: true)
    }

    func setSideButtonVisibility(to: Bool) {
        let buttonAlpha = 0.4
        leftButton.layer?.backgroundColor = .black.copy(
            alpha: to ? buttonAlpha : 0.0)
        rightButton.layer?.backgroundColor = .black.copy(
            alpha: to ? buttonAlpha : 0.0)
    }

    func checkBoot(skipInstallCheck _: Bool = false) {
        DispatchQueue.main.async {
            self.updateKoreanLoginControls()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        loginSheetWinController =
            storyboard?.instantiateController(withIdentifier: "LoginSheet")
            as? NSWindowController
        installerWinController =
            storyboard?.instantiateController(withIdentifier: "InstallerWindow")
            as? NSWindowController
        patchWinController =
            storyboard?.instantiateController(withIdentifier: "PatchSheet")
            as? NSWindowController
        repairWinController =
            storyboard?.instantiateController(withIdentifier: "RepairSheet")
            as? NSWindowController
        patchController =
            patchWinController!.contentViewController! as? PatchController
        repairController =
            repairWinController!.contentViewController! as? RepairController
        loadKoreanCaptcha()
    }

    private func populateNews(_ info: Frontier.Info) {
        DispatchQueue.main.async {
            self.topicsTable.add(items: info.topics)
            self.newsTable.add(items: info.pinned + info.news)
        }
    }

    private func populateBanners(_ banners: [Frontier.BannerRoot.Banner]) {
        DispatchQueue.main.async {
            self.scrollView.banners = banners
        }
    }

    private func update() {
        autoLoginCheck.isHidden = true
        otpCheck.isHidden = true
        otpField.isHidden = true

        let storedUsername = Settings.storedUsername ?? ""
        userField.stringValue = storedUsername
        passwdField.stringValue = ""

        guard !storedUsername.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let credentials = Settings.credentials else { return }
            DispatchQueue.main.async {
                guard let self,
                    self.userField.stringValue == storedUsername,
                    self.passwdField.stringValue.isEmpty
                else { return }
                self.passwdField.stringValue = credentials.password
            }
        }
    }

    @objc func update(_ sender: userMenuItem) {
        userField.stringValue = sender.credentials.username
        passwdField.stringValue = sender.credentials.password
        setupOTP()
    }

    @IBAction func showAccounts(_ sender: Any) {
        userMenu.items = []
        let accounts = LoginCredentials.accounts
        for account in accounts {
            let item = userMenuItem(
                title: account.username, action: #selector(update(_:)),
                keyEquivalent: "")
            item.credentials = account
            userMenu.items += [item]
        }
        userMenu.popUp(
            positioning: userMenu.item(at: 0), at: NSPoint(x: 0, y: 29),
            in: userField)
    }

    @IBAction func autoLoginStateChange(_ sender: NSButton) {
        Settings.autoLogin = sender.state == .on

        if Settings.autoLogin {
            let alert: NSAlert = .init()
            alert.messageText = NSLocalizedString(
                "AUTOLOGIN_MESSAGE", comment: "")
            alert.informativeText = NSLocalizedString(
                "AUTOLOGIN_INFORMATIVE", comment: "")
            alert.alertStyle = .informational
            alert.addButton(
                withTitle: NSLocalizedString("BUTTON_OK", comment: ""))

            alert.runModal()
        }
    }

    @IBAction func doLogin(_ sender: Any) {
        doLogin()
    }

    @IBAction func refreshKoreanCaptcha(_ sender: Any) {
        loadKoreanCaptcha(force: true)
    }

    @IBAction func doRepair(_ sender: Any) {
        doLogin(repair: true)
    }

    @IBAction func scrollLeft(_ sender: NSButton) {
        scrollView.scrollLeft()
    }

    @IBAction func scrollRight(_ sender: NSButton) {
        scrollView.scrollRight()
    }

    func problemConfigurationCheck() -> Bool {
        if FirstAidModel().cfgCheckSevereProblems() {
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            appDelegate.openFirstAid(self)
            return true
        }
        return false
    }

    func doLogin(repair _: Bool = false) {
        doKoreanLogin()
    }

    private func doKoreanLogin() {
        if problemConfigurationCheck() {
            return
        }

        let username = userField.stringValue.trimmingCharacters(
            in: .whitespacesAndNewlines)
        let password = passwdField.stringValue
        let captchaCode = captchaField.stringValue.trimmingCharacters(
            in: .whitespacesAndNewlines)

        guard !username.isEmpty else {
            showKoreanLoginValidation(
                "아이디를 입력해 주세요.", firstResponder: userField)
            return
        }
        guard !password.isEmpty else {
            showKoreanLoginValidation(
                "비밀번호를 입력해 주세요.", firstResponder: passwdField)
            return
        }
        guard captchaReady, !captchaLoading else {
            showKoreanLoginValidation(
                "보안문자를 먼저 불러와 주세요.",
                firstResponder: captchaRefreshButton)
            return
        }
        guard captchaCode.count == 5 else {
            showKoreanLoginValidation(
                "자동 입력 방지 문자 5자를 입력해 주세요.",
                firstResponder: captchaField)
            return
        }

        koreanLoginInProgress = true
        captchaReady = false
        captchaStatusLabel.stringValue = "로그인 확인 중…"
        updateKoreanLoginControls()

        view.window?.beginSheet(loginSheetWinController!.window!)
        Settings.credentials = LoginCredentials(
            username: username,
            password: password)

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            do {
                postLoginStatus("한국 서버 패치 확인 중")
                let patchPlan = try KoreanLauncher.pendingPatches()
                if !patchPlan.pendingPatches.isEmpty {
                    DispatchQueue.main.sync {
                        loginSheetWinController?.window?.close()
                    }
                    startPatch(patchPlan.pendingPatches)
                    let verification = try KoreanLauncher.pendingPatches()
                    guard verification.pendingPatches.isEmpty else {
                        throw KoreanLauncherError(
                            code: "PatchVerificationFailed",
                            stage: "patch",
                            serverCode: nil,
                            detail: "패치 설치 후에도 적용되지 않은 한국 서버 패치가 남아 있습니다.")
                    }
                    KoreanLauncher.resetSession()
                    DispatchQueue.main.async { [self] in
                        koreanLoginInProgress = false
                        captchaStatusLabel.stringValue =
                            "패치 완료 · 보안문자를 새로 불러옵니다"
                        loadKoreanCaptcha(force: true)
                    }
                    return
                }

                guard FFXIVApp().installed else {
                    throw FFXIVLoginError.noInstall
                }

                DispatchQueue.global(qos: .utility).async {
                    DiscordBridge.setPresence()
                }
                // This login flow already runs off the main thread. Complete
                // the DXMT synchronization before consuming the one-time game
                // token so an existing prefix cannot start with stale Wine DLLs.
                GraphicsInstaller.ensureBackend()

                postLoginStatus("로그인 중")
                let loginPayload = try KoreanLauncher.login(
                    username: username,
                    password: password,
                    captchaCode: captchaCode)

                if loginPayload.otpRequired {
                    var otpErrorMessage: String?
                    while true {
                        postLoginStatus(
                            otpErrorMessage == nil
                                ? "OTP 입력 대기 중" : "OTP 재입력 대기 중")
                        let otp = try promptKoreanOtp(
                            errorMessage: otpErrorMessage)
                        postLoginStatus("OTP 확인 중")
                        do {
                            try KoreanLauncher.submitOtp(otp)
                            break
                        } catch let error as KoreanLauncherError
                            where error.code == "OtpRejected"
                        {
                            Log.warning(
                                "[KOREA] OTP was rejected; prompting again")
                            otpErrorMessage =
                                "인증 번호가 올바르지 않습니다. 다시 입력해 주세요."
                        }
                    }
                }

                var dalamudOk = false
                if Settings.dalamudEnabled {
                    postLoginStatus("한국 전용 Dalamud 준비 중")
                    let state =
                        Dalamud.InstallState(rawValue: getDalamudInstallState())
                        ?? .failed
                    dalamudOk = state == .ok
                    if !dalamudOk {
                        Log.warning(
                            "[KOREA] Dalamud is unavailable; launching without injection")
                    }
                }
                postLoginStatus("게임 시작 중")
                let process = try KoreanLauncher.startGame(
                    dalamudOk: dalamudOk,
                    noPlugins: Settings.dalamudSafeMode)
                DispatchQueue.main.async { [self] in
                    loginSheetWinController?.window?.close()
                    view.window?.close()
                }
                AddOn.launchNotify()
                let exitCode = process.exitCode
                Log.information("Game exited with exit code \(exitCode)")
                DispatchQueue.main.async {
                    if exitCode != 0 && Settings.nonZeroExitError {
                        let alert = NSAlert()
                        alert.addButton(
                            withTitle: NSLocalizedString(
                                "BUTTON_OK", comment: ""))
                        alert.alertStyle = .critical
                        alert.messageText = NSLocalizedString(
                            "GAME_START_FAILURE", comment: "")
                        alert.informativeText = NSLocalizedString(
                            "GAME_START_FAILURE_INFORMATIONAL", comment: "")
                        alert.runModal()
                    } else if Settings.exitWithGame {
                        Util.quit()
                    }
                }
            } catch is CancellationError {
                KoreanLauncher.resetSession()
                DispatchQueue.main.async { [self] in
                    loginSheetWinController?.window?.close()
                    koreanLoginInProgress = false
                    loadKoreanCaptcha(force: true)
                }
            } catch {
                KoreanLauncher.resetSession()
                DispatchQueue.main.async { [self] in
                    loginSheetWinController?.window?.close()
                    koreanLoginInProgress = false
                    let alert = NSAlert()
                    alert.addButton(
                        withTitle: NSLocalizedString("BUTTON_OK", comment: ""))
                    alert.alertStyle = .critical
                    alert.messageText = "한국 서버 실행 오류"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                    loadKoreanCaptcha(force: true)
                }
            }
        }
    }

    private func loadKoreanCaptcha(force: Bool = false) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard force || (!captchaReady && !captchaLoading) else { return }
        guard !koreanLoginInProgress else { return }

        let requestID = UUID()
        captchaRequestID = requestID
        captchaReady = false
        captchaLoading = true
        captchaImageView.image = NSImage(
            systemSymbolName: "hourglass",
            accessibilityDescription: "보안문자 불러오는 중")
        captchaField.stringValue = ""
        captchaField.placeholderString = "불러오는 중…"
        captchaStatusLabel.stringValue = "자동 입력 방지 · 불러오는 중…"
        updateKoreanLoginControls()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let payload = try KoreanLauncher.prepareLogin()
                guard let encodedImage = payload.captchaImageBase64,
                    let imageData = Data(base64Encoded: encodedImage)
                else {
                    throw KoreanLauncherError(
                        code: "InvalidCaptchaImage",
                        stage: "captcha",
                        serverCode: nil,
                        detail: "보안문자 이미지를 읽을 수 없습니다.")
                }

                DispatchQueue.main.async {
                    guard let self, self.captchaRequestID == requestID else {
                        return
                    }
                    guard let image = NSImage(data: imageData) else {
                        self.finishCaptchaLoadFailure(
                            "보안문자 이미지를 표시할 수 없습니다.")
                        return
                    }
                    self.captchaImageView.image = image
                    self.captchaField.placeholderString =
                        "자동 입력 방지 (5자)"
                    self.captchaStatusLabel.stringValue =
                        "자동 입력 방지 (5자)"
                    self.captchaLoading = false
                    self.captchaReady = true
                    self.updateKoreanLoginControls()

                    if !self.userField.stringValue.isEmpty,
                        !self.passwdField.stringValue.isEmpty
                    {
                        self.view.window?.makeFirstResponder(self.captchaField)
                    }
                }
            } catch {
                KoreanLauncher.resetSession()
                DispatchQueue.main.async {
                    guard let self, self.captchaRequestID == requestID else {
                        return
                    }
                    Log.error("[KOREA] CAPTCHA load failed: \(error)")
                    self.finishCaptchaLoadFailure(
                        "불러오기 실패 · 새로고침을 눌러주세요")
                }
            }
        }
    }

    private func finishCaptchaLoadFailure(_ message: String) {
        captchaLoading = false
        captchaReady = false
        captchaImageView.image = NSImage(
            systemSymbolName: "exclamationmark.triangle",
            accessibilityDescription: message)
        captchaField.placeholderString = "보안문자 불러오기 실패"
        captchaStatusLabel.stringValue = message
        updateKoreanLoginControls()
    }

    private func updateKoreanLoginControls() {
        let canLogin = captchaReady && !captchaLoading
            && !koreanLoginInProgress
        loginButton.isEnabled = canLogin
        touchBarLoginButton.isEnabled = canLogin
        captchaField.isEnabled = canLogin
        captchaRefreshButton.isEnabled = !captchaLoading
            && !koreanLoginInProgress
    }

    private func showKoreanLoginValidation(
        _ message: String, firstResponder: NSResponder
    ) {
        captchaStatusLabel.stringValue = message
        NSSound.beep()
        view.window?.makeFirstResponder(firstResponder)
    }

    private func postLoginStatus(_ status: String) {
        Log.information("[KOREA] \(status)")
        NotificationCenter.default.post(
            name: .loginInfo,
            object: nil,
            userInfo: [Notification.status.info: status])
    }

    private func promptKoreanOtp(errorMessage: String?) throws -> String {
        let semaphore = DispatchSemaphore(value: 0)
        var result: KoreanOtpPromptResult = .cancelled

        DispatchQueue.main.async { [self] in
            loginSheetWinController?.window?.close()

            guard let parentWindow = view.window else {
                semaphore.signal()
                return
            }

            let promptController = KoreanOtpPromptController(
                errorMessage: errorMessage)
            koreanOtpPromptController = promptController
            promptController.present(for: parentWindow) { [self] response in
                result = response
                koreanOtpPromptController = nil
                semaphore.signal()
            }
        }

        semaphore.wait()
        switch result {
        case .submitted(let otp):
            DispatchQueue.main.sync { [self] in
                view.window?.beginSheet(loginSheetWinController!.window!)
            }
            return otp
        case .cancelled:
            throw CancellationError()
        }
    }

    func startPatch(_ patches: [Patch]) {
        if Thread.isMainThread {
            view.window?.beginSheet(patchWinController!.window!)
        } else {
            DispatchQueue.main.sync { [self] in
                view.window?.beginSheet(patchWinController!.window!)
            }
        }
        patchController?.install(patches)
    }

    @IBAction func tapTroubleshooting(_ sender: Any) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.openFirstAid(self)
    }

    @IBAction func tapBunnyHUD(_ sender: Any) {
        BunnyHUD.launch()
    }
}

private enum KoreanOtpPromptResult {
    case submitted(String)
    case cancelled
}

private final class KoreanOtpPromptController: NSObject, NSTextFieldDelegate {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 380, height: 190),
        styleMask: [.titled],
        backing: .buffered,
        defer: false)
    private let inputField = NSTextField()
    private let errorLabel = NSTextField(labelWithString: "")
    private let submitButton = NSButton(
        title: "확인", target: nil, action: nil)
    private var completion: ((KoreanOtpPromptResult) -> Void)?

    init(errorMessage: String?) {
        super.init()
        configure(errorMessage: errorMessage)
    }

    func present(
        for parentWindow: NSWindow,
        completion: @escaping (KoreanOtpPromptResult) -> Void
    ) {
        self.completion = completion
        parentWindow.beginSheet(panel)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            panel.makeFirstResponder(inputField)
            inputField.selectText(nil)
        }
    }

    private func configure(errorMessage: String?) {
        panel.title = "U-OTP 인증"
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .documentWindow

        guard let contentView = panel.contentView else { return }

        let titleLabel = NSTextField(labelWithString: "U-OTP 인증번호")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.frame = NSRect(x: 24, y: 145, width: 332, height: 24)

        let guideLabel = NSTextField(
            labelWithString: "OTP 앱에 표시된 숫자를 입력하세요.")
        guideLabel.textColor = .secondaryLabelColor
        guideLabel.frame = NSRect(x: 24, y: 119, width: 332, height: 18)

        errorLabel.stringValue = errorMessage ?? ""
        errorLabel.textColor = .systemRed
        errorLabel.lineBreakMode = .byTruncatingTail
        errorLabel.frame = NSRect(x: 24, y: 91, width: 332, height: 18)

        inputField.frame = NSRect(x: 24, y: 51, width: 332, height: 30)
        inputField.font = NSFont.monospacedDigitSystemFont(
            ofSize: 19, weight: .regular)
        inputField.alignment = .center
        inputField.placeholderString = "인증 번호 입력"
        inputField.contentType = .oneTimeCode
        inputField.delegate = self
        inputField.target = self
        inputField.action = #selector(submit)
        inputField.setAccessibilityLabel("U-OTP 인증번호")

        let cancelButton = NSButton(
            title: "취소", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.frame = NSRect(x: 194, y: 12, width: 78, height: 32)

        submitButton.target = self
        submitButton.action = #selector(submit)
        submitButton.bezelStyle = .rounded
        submitButton.keyEquivalent = "\r"
        submitButton.isEnabled = false
        submitButton.frame = NSRect(x: 278, y: 12, width: 78, height: 32)
        panel.defaultButtonCell = submitButton.cell as? NSButtonCell
        panel.initialFirstResponder = inputField

        for view in [
            titleLabel, guideLabel, errorLabel, inputField, cancelButton,
            submitButton,
        ] {
            contentView.addSubview(view)
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        let original = inputField.stringValue
        let filtered = Self.asciiDigits(in: original)
        if filtered != original {
            inputField.stringValue = filtered
            inputField.currentEditor()?.selectedRange = NSRange(
                location: filtered.utf16.count, length: 0)
            NSSound.beep()
        }
        submitButton.isEnabled = !filtered.isEmpty
    }

    @objc private func submit() {
        let otp = Self.asciiDigits(in: inputField.stringValue)
        guard !otp.isEmpty else {
            errorLabel.stringValue = "인증번호를 입력해 주세요."
            panel.makeFirstResponder(inputField)
            return
        }
        finish(with: .submitted(otp))
    }

    @objc private func cancel() {
        finish(with: .cancelled)
    }

    private func finish(with result: KoreanOtpPromptResult) {
        guard let completion else { return }
        self.completion = nil
        if let parent = panel.sheetParent {
            parent.endSheet(panel)
        }
        panel.orderOut(nil)
        completion(result)
    }

    private static func asciiDigits(in value: String) -> String {
        value.filter { character in
            guard character.unicodeScalars.count == 1,
                let scalar = character.unicodeScalars.first
            else { return false }
            return (48...57).contains(Int(scalar.value))
        }
    }
}

class userMenuItem: NSMenuItem {
    var credentials: LoginCredentials!
}

final class BannerView: NSImageView {
    var banner: Frontier.BannerRoot.Banner? {
        didSet {
            let bannerURL = URL(string: banner!.lsbBanner)!
            DispatchQueue.global(qos: .background).async { [self] in
                let bannerImage = Frontier.fetchImage(
                    url: bannerURL)
                DispatchQueue.main.async { [self] in
                    image = bannerImage
                }
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        if let banner = banner {
            let url = URL(string: banner.link)!
            NSWorkspace.shared.open(url)
        }
    }
}

final class AnimatingScrollView: NSScrollView {
    private var width: CGFloat {
        return contentSize.width
    }

    private var height: CGFloat {
        return contentSize.height
    }

    private let animationDuration = 2.0
    private let stayDuration = 8.0
    private var index = 0
    private var timer = Timer()

    var banners: [Frontier.BannerRoot.Banner]? {
        didSet {
            let banners = banners!
            documentView?.setFrameSize(
                NSSize(width: width * CGFloat(banners.count), height: height))
            for (i, banner) in banners.enumerated() {
                let bannerView = BannerView()
                bannerView.frame = CGRect(
                    x: CGFloat(i) * width, y: 0, width: width, height: height)
                bannerView.imageScaling = .scaleProportionallyUpOrDown
                bannerView.banner = banner
                documentView?.addSubview(bannerView)
            }
            startTimer()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        DispatchQueue.main.async { [self] in
            let trackingArea = NSTrackingArea(
                rect: bounds,
                options: [.activeInKeyWindow, .mouseEnteredAndExited],
                owner: self,
                userInfo: nil)
            addTrackingArea(trackingArea)
        }
    }

    func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(
            withTimeInterval: stayDuration, repeats: true,
            block: { _ in
                DispatchQueue.main.async {
                    self.animate()
                }
            })
    }

    func stopTimer() {
        timer.invalidate()
    }

    // This will override and cancel any running scroll animations
    override public func scroll(_ clipView: NSClipView, to point: NSPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contentView.setBoundsOrigin(point)
        CATransaction.commit()
        super.scroll(clipView, to: point)
        index = Int(floor((point.x + width / 2) / width))
        let snap_x = CGFloat(index) * width
        scroll(
            toPoint: NSPoint(x: snap_x, y: 0),
            animationDuration: animationDuration)
        startTimer()
    }

    private func scroll(toPoint: NSPoint, animationDuration: Double) {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = animationDuration
        contentView.animator().setBoundsOrigin(toPoint)
        reflectScrolledClipView(contentView)
        NSAnimationContext.endGrouping()
    }

    private func animate() {
        guard let banners = banners else { return }
        index = (index + 1) % banners.count
        scroll(
            toPoint: NSPoint(x: Int(width) * index, y: 0),
            animationDuration: animationDuration)
    }

    func scrollRight() {
        guard let banners = banners, index < banners.count - 1 else {
            return
        }
        startTimer()
        index += 1
        scroll(
            toPoint: NSPoint(x: Int(width) * index, y: 0),
            animationDuration: animationDuration)
    }

    func scrollLeft() {
        guard banners != nil, index > 0 else {
            return
        }
        startTimer()
        index -= 1
        scroll(
            toPoint: NSPoint(x: Int(width) * index, y: 0),
            animationDuration: animationDuration)
    }

    override func mouseEntered(with theEvent: NSEvent) {
        super.mouseEntered(with: theEvent)
        NotificationCenter.default.post(name: .bannerEnter, object: nil)
    }

    override func mouseExited(with theEvent: NSEvent) {
        super.mouseExited(with: theEvent)
        NotificationCenter.default.post(name: .bannerLeft, object: nil)
    }
}
