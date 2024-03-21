//
//  CMRFullRecordWithRulerViewController.swift
//  ISCCamera
//
//  Created by TrucPham on 15/06/2023.
//  Copyright © 2023 fun.sdk.ftel.vn.su4. All rights reserved.
//

import Foundation
class CMRFullRecordWithRulerViewController: UIBaseViewController {
    
    //MARK: TrucPN3
    var readyToPlay = false
    var playingItem : (Int, Int, Int) = (0,0, -1)
    let rulerControl = TPRulerPicker()
    lazy var indicatorLabel: UILabel = {
        $0.font = .semiboldAutoSize(20)
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.textColor = .black
        $0.textAlignment = .center
        return $0
    }(UILabel())
    
    fileprivate let containerView = UIView()
    fileprivate let scrVi : UIScrollView = {
        let v = UIScrollView()
        v.minimumZoomScale = 1
        v.maximumZoomScale = 10
        v.bounces = false
        v.bouncesZoom = false
        if #available(iOS 11.0, *) {
            v.contentInsetAdjustmentBehavior = .never
        }
        v.showsHorizontalScrollIndicator = false
        v.showsVerticalScrollIndicator = false
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    fileprivate let fullRecView = MPplayerLocalVi()
    fileprivate let infoView = InfoDateView()
    fileprivate let spacingView = UIView()
    
    fileprivate let playBackImg : UIImageView = {
        let imgVi = UIImageView()
        let preferLang = Locale.preferredLanguages.first
        imgVi.image = preferLang == "vi-VN" ? #imageLiteral(resourceName: "vi-playback-live") : #imageLiteral(resourceName: "en-playback-live")
        imgVi.contentMode = .scaleAspectFit
        return imgVi
    }()
    
    
    
    let backNavVi : LeftNavItemContainer = {
        let vi = LeftNavItemContainer()
        vi.backBtn.setImage(UIImage(named: "navBackWhite"), for: .normal)
        vi.leftTitleNavBar.setFontSize(fontSize: 18)
        vi.leftTitleNavBar.textColor = .white
        vi.leftTitleNavBar.text = isViLang ? "Ghi hình 24/7 " : "24/7 recording"
        vi.spaceBtnAndTitle?.constant = 8
        return vi
    }()
    
    fileprivate let initLoadingView = LoadingView()
    fileprivate let fullRecSpinKit = MPActIndiView()
    fileprivate let playerSpinKit = MPActIndiView()
    
    fileprivate let playerControlView = FullRecordControlView()
    
    private let initWidth = UIScreen.main.bounds.width
    let hDimensionInfoView : CGFloat = 74
    let hDimensionSpacingView : CGFloat = 0.5
    let bottomDimenSliderBar : CGFloat = -20
    private var heightContainerView : NSLayoutConstraint?
    private var heightInfoView : NSLayoutConstraint?
    private var heightSpaceView : NSLayoutConstraint?
    private var bottomSliderBar : NSLayoutConstraint?
    private var leadingSliderBar : NSLayoutConstraint?
    private var trailingSliderBar : NSLayoutConstraint?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.modeOrientation = .upsideDown
        self.hideNavigationBar = true
        setupUI()
        setDelegateAndRegis()
        handleBtnPressed()
    }
    func reloadRulerData(){
        let records = arrAllVideoData.filter { data in
            return data is RecordInfo || (data is RecordPageModel && (data as! RecordPageModel).is_anr ?? false)
        } as! [RecordInfo]
        let clouds = arrAllVideoData.filter { data in
            return data is RecordPageModel && !((data as! RecordPageModel).is_anr ?? false)
        } as! [RecordPageModel]
        rulerControl.dataColors = [
            (records.map({ record in
                let from = Int("\(record.timeBegin.day)/\(record.timeBegin.month)/\(record.timeBegin.year) \(record.timeBegin.hour):\(record.timeBegin.minute):\(record.timeBegin.second)".toDate("dd/MM/yyyy HH:mm:ss")!.timeIntervalSince1970)
                
                let to = Int("\(record.timeEnd.day)/\(record.timeEnd.month)/\(record.timeEnd.year) \(record.timeEnd.hour):\(record.timeEnd.minute):\(record.timeEnd.second)".toDate("dd/MM/yyyy HH:mm:ss")!.timeIntervalSince1970)
                return (from, to)
            }), .red),
            
            (clouds.map({ cloud in
                let from = Int(cloud.recordtimestamp?.toDate("yyyy-MM-dd HH:mm:ss")?.timeIntervalSince1970 ?? 0)
                let to = Int(cloud.end_time?.toDate("yyyy-MM-dd HH:mm:ss")?.timeIntervalSince1970 ?? 0)
                return (from, to)
            }), .blue)
        ]
    }
    func rulerPickerSetup(){
        guard let dataReceived = dataReceived else { return }
        rulerControl.frame = .init(origin: .init(x: 0, y: self.view.center.y), size: .init(width: self.view.bounds.width, height: 100))
        let cDate = Int(Date().timeIntervalSince1970)
        let startDate = Int(dataReceived.startDate.removeTimeStamp.timeIntervalSince1970)
        let weightMetrics = TPRulerPickerConfiguration.Metrics(
            minimumValue: startDate,
            defaultValue: cDate,
            maximumValue: cDate,
            valueSpacing: 360,
            divisions: 10,
            fullLineSize: 40,
            midLineSize: 32,
            smallLineSize: 22,
            indicatorLineSize: 100)
        rulerControl.configuration = TPRulerPickerConfiguration(scrollDirection: .horizontal,alignment: .start, lineSpacing: 15,lineAndLabelSpacing : 30, metrics: weightMetrics)
        rulerControl.font = UIFont(name: "AmericanTypewriter-Bold", size: 12)!
        rulerControl.dataSource = self
        rulerControl.delegate = self
        rulerControl.tintColor = .white
        rulerControl.backgroundColor = .lightGray.withAlphaComponent(0.5)
        self.view.backgroundColor = .white
        self.view.addSubview(indicatorLabel)
        NSLayoutConstraint.activate([
            indicatorLabel.centerXAnchor.constraint(equalTo: self.rulerControl.centerXAnchor),
            indicatorLabel.bottomAnchor.constraint(equalTo: self.rulerControl.topAnchor, constant: -15),
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAnrDownloadWhenAppBackground), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(checkAnrDownloadWhenAppBackground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        //        removeVideosDownloadedIfHadInCache()
    }
    
    //MARK:- Delegate declare and Setup interface of VC
    
    //TODO: Delegate declare
    fileprivate func setDelegateAndRegis() {
        scrVi.delegate = self
        
        fullRecView.delegate = self
        mpConfig.delegate = self
        mpConfig.mpInit()
        anrDownloader.delegate = self
        anrDownloader.initDataSource()
    }
    
    //TODO: Setup interface
    
    fileprivate func setupUI() {
        view.backgroundColor = #colorLiteral(red: 0.1960784314, green: 0.2117647059, blue: 0.262745098, alpha: 1)
        [containerView, infoView, spacingView,rulerControl, fullRecSpinKit, initLoadingView, backNavVi].forEach{view.addSubview($0)}
        
        setupPlayerUiView()
        setupInfoView()
        rulerPickerSetup()
        
        fullRecSpinKit.fillSuperview()
        initLoadingView.fillSuperview()
    }
    
    fileprivate func setupPlayerUiView() {
        containerView.anchor(top: view.readableContentGuide.topAnchor, leading: view.leadingAnchor, bottom: nil, trailing: view.trailingAnchor)
        containerView.backgroundColor = .black
        heightContainerView = containerView.heightAnchor.constraint(equalToConstant: view.frame.width / 16 * 9)
        heightContainerView?.isActive = true
        
        [scrVi, playBackImg,playerControlView, cmrOfflineView, cmrCantConnectView, retryView, playerSpinKit].forEach{ containerView.addSubview($0) }
        [scrVi, playerControlView, cmrOfflineView, cmrCantConnectView, playerSpinKit].forEach{$0.fillSuperview()}
        retryView.centerInSuperview(size: .init(width: 205, height: 78))
        [cmrOfflineView, cmrCantConnectView, retryView].forEach{$0.isHidden = true}
        
        playBackImg.anchor(top: containerView.topAnchor, leading: nil, bottom: nil, trailing: containerView.readableContentGuide.trailingAnchor, padding: .init(top: 25, left: 0, bottom: 0, right: 0), size: .init(width: 91, height: 17))
        
        backNavVi.anchor(top: containerView.topAnchor, leading: containerView.leadingAnchor, bottom: nil, trailing: nil, padding: .init(top: 10, left: 14, bottom: 0, right: 0), size: .init(width: 0, height: 40))
        backNavVi.widthAnchor.constraint(lessThanOrEqualToConstant: 200).isActive = true
    }
    
    fileprivate func setupInfoView() {
        infoView.anchor(top: containerView.bottomAnchor, leading: view.leadingAnchor, bottom: nil, trailing: view.trailingAnchor)
        heightInfoView = infoView.heightAnchor.constraint(equalToConstant: hDimensionInfoView)
        heightInfoView?.isActive = true
        
        spacingView.backgroundColor = .lightGray
        spacingView.anchor(top: infoView.bottomAnchor, leading: view.leadingAnchor, bottom: nil, trailing: view.trailingAnchor)
        heightSpaceView = spacingView.heightAnchor.constraint(equalToConstant: hDimensionSpacingView)
        heightSpaceView?.isActive = true
    }
    
    
    //TODO: UI portrait or landscape
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        scrVi.zoomScale = 1
        coordinator.animate(alongsideTransition: { (context) in
            if size.width > size.height {
                self.landscapeLayoutUI(size)
            } else {
                self.portraitLayoutUI(size)
            }
            UIView.animate(withDuration: 0.5) {
                self.view.layoutIfNeeded()
            }
        }, completion: nil)
    }
    
    fileprivate func landscapeLayoutUI(_ size : CGSize){
        heightContainerView?.constant = size.height
        [heightInfoView, infoView.heightSwAutoPlay, infoView.heightAutoPlayLbl, infoView.heightDateLbl, infoView.topDateLbl, infoView.topDetailDateLbl, infoView.botDetailDateLbl, heightSpaceView].forEach{$0?.constant = 0}
        bottomSliderBar?.constant = self.bottomDimenSliderBar
        fullRecView.frame.size = CGSize(width: containerView.frame.width, height: initWidth)
        leadingSliderBar?.constant = 16
        trailingSliderBar?.constant = -16
    }
    
    fileprivate func portraitLayoutUI(_ size : CGSize){
        heightContainerView?.constant = size.width / 16 * 9
        heightInfoView?.constant = hDimensionInfoView
        infoView.heightSwAutoPlay?.constant = infoView.hDimensionSwAutoPlay
        infoView.heightAutoPlayLbl?.constant = infoView.hDimensionAutoPlayLbl
        infoView.heightDateLbl?.constant = infoView.hDimensionDateLbl
        infoView.topDateLbl?.constant = infoView.topDimenDateLbl
        infoView.topDetailDateLbl?.constant = infoView.topDimenDetailDateLbl
        infoView.botDetailDateLbl?.constant = infoView.botDimenDetailDateLbl
        fullRecView.frame.size = CGSize(width: initWidth, height: initWidth * 9 / 16)
        scrVi.contentSize = fullRecView.frame.size
        heightSpaceView?.constant = hDimensionSpacingView
        [bottomSliderBar,leadingSliderBar,trailingSliderBar].forEach{$0?.constant = 0}
    }
    
    //MARK: - Get Full Array Videos
    
    fileprivate var totalPageMustLoad: Int?
    fileprivate var currentPageLoad = 1
    fileprivate var isAnrReversed = false
    fileprivate let sdMethodTxt = "sd"
    fileprivate var firstInfo = FuReFirstInfo(method: "cloud", showVolumeIcon: false, showDownloadIcon: false, showAnrIcon: false, isDecreasing: false)
    
    var dataReceived : FuReDataReceived? {
        didSet {
            guard let data = dataReceived, let info = data.firstInfoLoaded  else {return}
            firstInfo = info
            playerControlView.showSpeaker = info.showVolumeIcon
            loadVideoFromServerByDateReceived()
        }
    }
    
    fileprivate func loadVideoFromServerByDateReceived() {
        guard let data = dataReceived else {return}
        let setFormat = DateFormatter()
        setFormat.calendar = Calendar.appCalendar
        setFormat.dateFormat = "dd/MM/yyyy"
        infoView.detailDateLbl.text = setFormat.string(from: data.startDate)
        scrVi.addSubview(fullRecView)
        fullRecView.frame = CGRect(x: 0, y: 0, width: initWidth, height: initWidth * 9 / 16)
        fullRecView.initWithPlayerType(.Other, withCmrSerial: data.serial)
        updateDate()
    }
    
    fileprivate func updateDate() {
        guard let data = dataReceived else {return}
        let stDate = Calendar.appCalendar.date(bySettingHour: 0, minute: 0, second: 0, of: data.startDate)
        let etDate : Date? = Date()//Calendar.appCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: data.startDate)
        guard let st = stDate, let et = etDate else {return}
        datePlayVideo = FullRecDateModel(startDate: st, endDate: et)
    }
    
    fileprivate var datePlayVideo: FullRecDateModel? {
        didSet {
            guard let datePlay = datePlayVideo else {return}
            _ = firstInfo.method != sdMethodTxt ? getArrVideoFromServer(datePlay, "1") : loginCmrDevice()
        }
    }
    
    fileprivate var arrVideoFromServer : [RecordPageModel]? {
        didSet {
            if let arrSer = arrVideoFromServer {
                if currentPageLoad == 1 {
                    initLoadingView.isHidden = false
                }
                let checkAnr = findAnrIndex(fromIndex: 0)
                if let _ = checkAnr {
                    if isLoginCmrDeviceSuccess {
                        findAndHandleAnrObj(fromIdx: 0)
                    } else {
                        loginCmrDevice()
                    }
                } else {
                    arrAllVideoData += arrSer
                    arrAllVideoDataUpdateFinished()
                }
            }
        }
    }
    
    fileprivate var mpVideoAnrArray = [RecordInfo]() {
        didSet {
            if mpVideoAnrArray.count > 0 && !isArrAllVideoUpdateFinished{
                arrAllVideoData += isAnrReversed ? Array(mpVideoAnrArray.reversed()) : mpVideoAnrArray
                mpVideoAnrArray = [RecordInfo]()
                if let idx = tempIdxAnrQuery, idx + 1 < arrVideoFromServer!.count {
                    findAndHandleAnrObj(fromIdx: idx + 1)
                } else {
                    arrAllVideoDataUpdateFinished()
                }
            }
        }
    }
    
    fileprivate var arrAllVideoData = [Any]() {
        didSet {
            reloadRulerData()
        }
    }
    fileprivate let mpConfig = MPFileConfig()
    fileprivate var tempIdxAnrQuery: Int?
    fileprivate var isArrAllVideoUpdateFinished = false
    fileprivate var isPreparePlayAtFirstRow = false
    
    fileprivate func arrAllVideoDataUpdateFinished() {
        if currentPageLoad == 1 {
            isPreparePlayAtFirstRow = true
            showHideViewNoData(isHidden: !arrAllVideoData.isEmpty)
        }
        arrVideoFromServer = nil
        tempIdxAnrQuery = nil
        isArrAllVideoUpdateFinished = true
    }
    
    //TODO: Find Anr File From arrVideoFromServer
    
    fileprivate func findAndHandleAnrObj(fromIdx idx: Int) {
        if let indexCloudAnr = findAnrIndex(fromIndex: idx) {
            handleWhenIsAnrTrue(indexCloudAnr)
        } else {
            handleWhenIsAnrFalse(fromIdx: idx)
        }
    }
    
    fileprivate func findAnrIndex(fromIndex frIdx: Int) -> Int? {
        var anrIdx: Int?
        if let arrServer = arrVideoFromServer {
            for i in frIdx..<arrServer.count {
                if arrServer[i].is_anr == true {
                    anrIdx = i
                    break
                }
            }
        }
        return anrIdx
    }
    
    fileprivate func handleWhenIsAnrTrue(_ anrIsTrueIdx: Int) {
        guard let serverList = arrVideoFromServer else {return}
        if anrIsTrueIdx > 0 {
            if let idx = tempIdxAnrQuery {
                if (idx + 1) <= anrIsTrueIdx { // prevent crashed
                    arrAllVideoData += Array(serverList[(idx + 1)..<anrIsTrueIdx])
                }
            } else {
                arrAllVideoData += Array(serverList[0..<anrIsTrueIdx])
            }
        }
        anrQueryByFile(atCloudAnrIdx: anrIsTrueIdx)
    }
    
    fileprivate func handleWhenIsAnrFalse(fromIdx idx: Int) {
        if idx == 0 {
            if let arr = arrVideoFromServer {
                arrAllVideoData += arr
            }
        } else {
            arrAllVideoData += Array(arrVideoFromServer![idx ..< arrVideoFromServer!.count])
        }
        arrAllVideoDataUpdateFinished()
    }
    
    
    //TODO: Get Anr Files From Sd Card
    
    fileprivate var receivedAnrByFileResult = false
    fileprivate var timerArnByFileResult : Timer?
    
    fileprivate func anrQueryByFile(atCloudAnrIdx idx: Int) {
        tempIdxAnrQuery = idx
        let item = arrVideoFromServer![idx]
        handleGetAnrVideo(fromTime: item.recordtimestamp!, toTime: item.end_time!)
    }
    
    fileprivate func getAllSdCard() {
        guard let dateInfo = datePlayVideo else {return}
        initLoadingView.isHidden = false
        let recTime = Common.shared.convertFromDateToString(dateInfo.startDate, type: "yyyy-MM-dd HH:mm:ss")
        let endTime = Common.shared.convertFromDateToString(dateInfo.endDate, type: "yyyy-MM-dd HH:mm:ss")
        handleGetAnrVideo(fromTime: recTime, toTime: endTime)
    }
    
    fileprivate func handleGetAnrVideo(fromTime: String, toTime: String) {
        receivedAnrByFileResult = false
        guard let timeRange = prepareTimeRange(fromTime, toTime) else {return}
        transferTimeRangeToConfig(timeRange.fromTime, timeRange.toTime)
        mpConfig.mpGetVideoBetweenTimeRange(.COther)
        timerArnByFileResult?.invalidate()
        timerArnByFileResult = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(checkAnrByFileTimeout), userInfo: nil, repeats: false)
    }
    
    
    @objc fileprivate func checkAnrByFileTimeout() {
        if !receivedAnrByFileResult {
            if firstInfo.method != sdMethodTxt {
                guard let arrSer = arrVideoFromServer else {return}
                var arr = Array(arrSer[tempIdxAnrQuery! ..< arrSer.count])
                arr.removeAll{$0.is_anr == true}
                arrAllVideoData += arr
            }
            
            if arrAllVideoData.count > 0 {
                arrAllVideoDataUpdateFinished()
            } else {
                showHideViewNoData(isHidden: false)
            }
        }
    }
    
    fileprivate func prepareTimeRange(_ fromTime: String, _ toTime: String) -> FullRecTimeRangeModel? {
        guard let fromTime = stringDateToTimeModel(fromTime) else {return nil}
        guard let toTime = stringDateToTimeModel(toTime) else {return nil}
        return FullRecTimeRangeModel(fromTime: fromTime, toTime: toTime)
    }
    
    fileprivate func transferTimeRangeToConfig(_ fromTime: MPdate, _ toTime: MPdate) {
        mpConfig.sdStD = fromTime.mpDate as NSDate
        mpConfig.sdStH = fromTime.h
        mpConfig.sdStM = fromTime.m
        mpConfig.sdStS = fromTime.s
        
        mpConfig.sdEnD = toTime.mpDate as NSDate
        mpConfig.sdEnH = toTime.h
        mpConfig.sdEnM = toTime.m
        mpConfig.sdEnS = toTime.s
    }
    
    //TODO: Login Camera Device
    
    fileprivate var isLoginCmrDeviceSuccess = false
    fileprivate let cmrDeviceManager = ISCCameraDeviceManager.shared()
    fileprivate var loginTimer: Timer?
    
    fileprivate func loginCmrDevice() {
        guard let info = dataReceived?.cmrInfo else {return}
        if currentPageLoad == 1 {
            initLoadingView.isHidden = false
            loginTimer?.invalidate()
            loginTimer = Timer.scheduledTimer(withTimeInterval: 7, repeats: false, block: {[weak self] _ in
                guard let self = self else {return}
                self.showHideViewNoData(isHidden: false)
            })
        }
        let serial = info.serial ?? ""
        let loginName = info.account?.username ?? "admin"
        let deviceName = info.name ?? ""
        cmrDeviceManager.delegate = self
        guard let pw = CryptorManager.shared.decrypt(encryptedText: info.account?.password ?? "", password: ISCSession.getTokenDecrypt()) else {return}
        
        if let _ = cmrDeviceManager.getDeviceObject(bySN: serial) {
            cmrDeviceManager.changeDevicePsw(serial, loginName: loginName, password: pw)
            cmrDeviceManager.getDeviceChannel(serial, seq: Common.SEQ_LIVESTREAM)
        } else {
            cmrDeviceManager.addDevice(byDeviseSerialnumber: serial, deviceName: deviceName, devType: 0, seq: Common.SEQ_LIVESTREAM)
            cmrDeviceManager.changeDevicePsw(serial, loginName: loginName, password: pw)
        }
    }
    
    fileprivate func handleWhenReceivedLoginCmrDeviceResult(_ isSucess: Bool) {
        loginTimer?.invalidate()
        cmrDeviceManager.delegate = nil
        isLoginCmrDeviceSuccess = isSucess
        if isSucess {
            _ = firstInfo.method != sdMethodTxt ? findAndHandleAnrObj(fromIdx: 0) : getAllSdCard()
        } else {
            if var arrSer = arrVideoFromServer, firstInfo.method != sdMethodTxt{
                arrSer.removeAll{$0.is_anr == true}
                arrAllVideoData += arrSer
            }
            arrAllVideoDataUpdateFinished()
        }
    }
    
    //MARK: - Handle Actions
    
    fileprivate var stateSpeaker = CMRSessionDevice.VIDEO_WITH_SOUND
    
    fileprivate func handleBtnPressed() {
        containerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapToDisplayDimVi)))
        backNavVi.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapToTurnBack24hVC)))
        playerControlView.forwardCompleted = {[weak self] in
            self?.forwardBtnHandle()
        }
        playerControlView.backwardCompleted = {[weak self] in
            self?.backwardBtnHandle()
        }
        
        playerControlView.playPauseCompleted = {[weak self] in
            self?.handlePlayBtnPressed()
        }
        
        playerControlView.sliderDownCompleted = {[weak self] in
            self?.handleSlideTouchDown()
        }
        
        playerControlView.sliderUpCompleted = {[weak self] in
            self?.handleSliderAction()
        }
        
        playerControlView.fullScreenCompleted = {[weak self] in
            self?.fullScrBtnPressed()
        }
        
        playerControlView.speakerBtnCompleted = {[weak self] (state) in
            guard let videoState = self?.fullRecView.videoState, let isPause = self?.fullRecView.isPause else {return}
            if videoState == .Playing && !isPause {
                self?.fullRecView.openSound(state ? 100 : 0)
            }
            self?.stateSpeaker = state
            CMRSessionDevice.VIDEO_WITH_SOUND = state
        }
        
        retryView.retryImage.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(fuRecShowSpinkit)))
    }
    fileprivate func convertToDate(_ object : Any) -> (Date?, Date?) {
        var start : Date? = Date()
        var end : Date? = Date()
        if let record = object as? RecordInfo {
            start = "\(record.timeBegin.day)/\(record.timeBegin.month)/\(record.timeBegin.year) \(record.timeBegin.hour):\(record.timeBegin.minute):\(record.timeBegin.second)".toDate("dd/MM/yyyy HH:mm:ss")
            
            end = "\(record.timeEnd.day)/\(record.timeEnd.month)/\(record.timeEnd.year) \(record.timeEnd.hour):\(record.timeEnd.minute):\(record.timeEnd.second)".toDate("dd/MM/yyyy HH:mm:ss")
        }
        else if let cloud = object as? RecordPageModel {
            start = cloud.recordtimestamp?.toDate("yyyy-MM-dd HH:mm:ss")
            end = cloud.end_time?.toDate("yyyy-MM-dd HH:mm:ss")
        }
        return (start, end)
    }
    fileprivate func getCurrentItem() -> Int? {
        return self.arrAllVideoData.firstIndex(where: { object in
            let date = convertToDate(object)
            if let start = date.0, let end = date.1 {
                return Int(start.timeIntervalSince1970) < rulerControl.currentValue && Int(end.timeIntervalSince1970) > rulerControl.currentValue
            }
            return false
        })
    }
    
    //TODO: Nav bar back btn, play/pause, forward, backward
    
    @objc fileprivate func tapToDisplayDimVi() {
        playerControlView.isHidden.toggle()
        backNavVi.isHidden = playerControlView.isHidden
        
        if arrAllVideoData.count == 0 || !cmrCantConnectView.isHidden || !retryView.isHidden {
            playerControlView.isHidden = true
        }
    }
    
    @objc fileprivate func tapToTurnBack24hVC() {
        if DeviceInfo.Orientation.isLandscapeFromScreen {
            backNavVi.rippleView.beginRippleTouchUp(animated: true)
            ISCAppDelegate.AppUtility.lockOrientation(UIInterfaceOrientationMask.all, andRotateTo : .portrait)
            self.modeOrientation = .unknown
        }else {
            fullRecView.mpStopPlayVideo()
            UIView.animate(withDuration: 0.5) {
                self.popViewController(animated: true)
            }
        }
    }
    
    @objc fileprivate func handlePlayBtnPressed() {
        if isPreparePlayAtFirstRow {
            isPreparePlayAtFirstRow = false
            handlePlayVideo()
        } else {
            if fullRecView.isPause {
                playerControlView.setPlayButtonImage(false)
                
                if let _ = isCloudPlaying {
                    if let index = self.getCurrentItem(), let _ = arrAllVideoData[index] as? RecordInfo {
                        timerForListenAnrPlaying?.invalidate()
                        listenAnrPlaying = true
                    }
                    fullRecView.pauseOrResumePlay()
                    
                } else {
                    if let index = self.getCurrentItem(), let obj = arrAllVideoData[index] as? RecordPageModel {
                        handlePlayCloudFile(linkUrl: obj.file ?? "")
                    } else {
                        isCloudPlaying = false
                        fullRecView.mpViPlaySdByTime()
                    }
                }
                
                if stateSpeaker {
                    fullRecView.openSound(100)
                }

            } else {
                if let index = self.getCurrentItem(),  let _ = arrAllVideoData[index] as? RecordInfo {
                    timerForListenAnrPlaying?.invalidate()
                    listenAnrPlaying = false
                }
                playerControlView.setPlayButtonImage(true)
                fullRecView.pauseOrResumePlay()
                if stateSpeaker {
                    fullRecView.openSound(0)
                }

            }
        }
    }
    
    @objc fileprivate func forwardBtnHandle() {
        handleSlideTouchDown()
        let timePlayAnr = (timePlayingSdCard + 15) >= timeEndPlaySdCard ? (timeEndPlaySdCard - 5) : (timePlayingSdCard + 15)
        seekVideoToTime(currentTimeCloudPlaying + 23, timePlayAnr)
    }
    
    @objc fileprivate func backwardBtnHandle() {
        handleSlideTouchDown()
        let timePlayAnr = (timePlayingSdCard - 15) <= timeStartPlaySdCard ? timeStartPlaySdCard : (timePlayingSdCard - 15)
        seekVideoToTime(currentTimeCloudPlaying - 7, timePlayAnr)
    }
    
    @objc fileprivate func handleSlideTouchDown() {
        if !fullRecView.isPause {
            fullRecView.sliderTouchDown()
        }
    }

    //TODO: Silde Bar, Full Screen , Auto Play Actions
    
    @objc fileprivate func handleSliderAction() {
        if isPreparePlayAtFirstRow {return}
        seekVideoToTime(playerControlView.getCurrentTime(), playerControlView.getCurrentTime() + timeStartPlaySdCard)
    }
    
    fileprivate func seekVideoToTime(_ cloudTime: Int, _ anrTime: Int) {
        playerSpinKit.isHidden = false
        playerControlView.isHidden = true
        
        if fullRecView.isPause {
            playerControlView.setPlayButtonImage(false)
        }
        
        guard let cloudPlay = isCloudPlaying else {return}
        if cloudPlay {
            fullRecView.seek(toTime: cloudTime)
        } else {
            timerForListenAnrPlaying?.invalidate()
            listenAnrPlaying = false
            previousTimePlayingSdCard = 0
            fullRecView.mpSdCardSeek(anrTime)
            timerForListenAnrPlaying = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(changeListenAnrPlayingValue), userInfo: nil, repeats: false)
        }
        
        if stateSpeaker {
            fullRecView.openSound(100)
        }
    }
    
    @objc fileprivate func fullScrBtnPressed() {
        ISCAppDelegate.AppUtility.lockOrientation(UIInterfaceOrientationMask.all, andRotateTo : DeviceInfo.Orientation.isLandscapeFromScreen ? .portrait : .landscapeRight)
        self.modeOrientation = .unknown
    }

    fileprivate func switchBtnHandle() {
        if infoView.swAutoPlay.isOn {
            if !fullRecView.isPause { fullRecView.pauseOrResumePlay() }
            fullRecView.mpStopPlayVideo()
            fullRecView.dismissPlayView()
            
            let newIndex = self.playingItem.2 - 1
            isAnrIconTapped = false
            handlePlayVideo((newIndex > -1) ? newIndex : nil)
            playerControlView.setPlayButtonImage(false)
        }
    }
    
    
    //TODO: Handle ANR Img Action
     
    fileprivate let cmrOfflineView = CmrOffLineView()
    fileprivate let cmrCantConnectView : CmrOffLineView = {
        let vi = CmrOffLineView()
        vi.titleLbl.text = AppLanguage.fuRecCmrCantConnectTitle
        vi.detailTitleLbl.text = AppLanguage.fuRecCmrCantConnectDetailTitle
        vi.heightDetailLbl?.constant = 20
        return vi
    }()
    
    fileprivate let anrBackdropInfo : DimmingSaveView = {
        let vi = DimmingSaveView()
        vi.saveView.addOneBottomBtn()
        vi.saveView.heightDetailLbl?.constant = 24 * 4
        vi.heightBotVi = 169 + 24 * 4
        vi.saveView.titleLabel.text = AppLanguage.fuRecAnrBackdroptTitle
        vi.saveView.detailLabel.text = AppLanguage.fuRecBackdroptCmrOffDetailTitle
        vi.saveView.bottomButton.setTitle(AppLanguage.fuRecBackdropAnrBtnText, for: .normal)
        return vi
    }()
    
    fileprivate let anrBackdropCantConnect : DimmingSaveView = {
        let vi = DimmingSaveView()
        vi.saveView.addOneBottomBtn()
        vi.saveView.heightDetailLbl?.constant = 24 * 3
        vi.heightBotVi = 169 + 24 * 3
        vi.saveView.titleLabel.text = AppLanguage.fuRecAnrBackdroptTitle
        vi.saveView.detailLabel.text = AppLanguage.fuRecBackdroptCmrCantConnectDetailTitle
        vi.saveView.bottomButton.setTitle(AppLanguage.fuRecBackdropAnrBtnText, for: .normal)
        return vi
    }()
    
    fileprivate let anrBackdropDownload : DimmingSaveView = {
        let vi = DimmingSaveView()
        vi.saveView.addOneBottomBtn()
        vi.saveView.heightDetailLbl?.constant = 24 * 4
        vi.heightBotVi = 169 + 24 * 4
        vi.saveView.titleLabel.text = AppLanguage.fuRecAnrBackdroptTitle
        vi.saveView.detailLabel.text = AppLanguage.fuRecBackdropDownloadAnr
        vi.saveView.bottomButton.setTitle(AppLanguage.fuRecBackdropBtnDownload, for: .normal)
        return vi
    }()
    
    @objc fileprivate func handleAnrIconTapped(_ sender: UITapGestureRecognizer) {
//        let location = sender.location(in: tblDataView)
//        guard let index = tblDataView.indexPathForRow(at: location) else {return}
//        if index.row != currentIndex {
//            handleWhenCellFocus(index)
//        }
//        if let cell = tblDataView.cellForRow(at: index) as? FullRecordTblViCell {
//            cell.btnDownload.isUserInteractionEnabled = false
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                cell.btnDownload.isUserInteractionEnabled = true
//            }
//        }
//        fromHandleAnrIconTapped = true
//        apiCheckCmrOnOff()
    }
      
    fileprivate var resultAnrByTime: Int? {
        didSet {
            if let rst = resultAnrByTime, isAnrIconTapped{
                if rst >= 0 {
                    addAnrBackdropDownload()
                } else if rst == -10005 {
                    addAnrBackdrop(anrBackdropInfo)
                } else if rst < 0 {
                    addAnrBackdrop(anrBackdropCantConnect)
                }
                isAnrIconTapped = false
                resultAnrByTime = nil

                if rst >= 0 {
                    offlineOrCantConnectIndex = nil
                }
            }
        }
    }
    
    fileprivate var offlineOrCantConnectIndex : Int?

    fileprivate var isAnrIconTapped = false {
        didSet {
            if isAnrIconTapped && timeEndPlaySdCard != 0 {
                addAnrBackdropDownload()
                isAnrIconTapped = false
            } else if isAnrIconTapped && cmrOfflineView.isHidden == false {
                addAnrBackdrop(anrBackdropInfo)
                isAnrIconTapped = false
            } else if isAnrIconTapped && cmrCantConnectView.isHidden == false {
                addAnrBackdrop(anrBackdropCantConnect)
                isAnrIconTapped = false
            }
        }
    }
    
    fileprivate func addAnrBackdrop(_ vi: DimmingSaveView) {
        view.addSubview(vi)
        vi.fillSuperview()
        vi.showBottomView()
        vi.saveView.bottomButton.addTarget(self, action: #selector(removeAnrBackdrop), for: .touchUpInside)
    }
    
    @objc fileprivate func removeAnrBackdrop() {
        anrBackdropInfo.hideBottomView()
        anrBackdropCantConnect.hideBottomView()
    }
    
    fileprivate func addAnrBackdropDownload() {
        view.addSubview(anrBackdropDownload)
        anrBackdropDownload.fillSuperview()
        anrBackdropDownload.showBottomView()
        anrBackdropDownload.saveView.bottomButton.addTarget(self, action: #selector(handleAnrDownloadBtnPressed), for: .touchUpInside)
    }
    
    @objc fileprivate func handleAnrDownloadBtnPressed() {
        anrBackdropDownload.hideBottomView()
        if let _ = downloadIndex {
            stopDownloadVideo()
        }
        startDownloadVideo()
    }
    
    //MARK:- Handle Download Video
    
    fileprivate var downloadIndex: Int? {
        didSet {
        }
    }
    fileprivate let anrDownloader = MPViFileDownload()
    
    fileprivate var anrDownloadedPath : String? {
        didSet {
            if let path = anrDownloadedPath {
                handleWhenDownloadSuccess(path)
            }
        }
    }
    
    @objc fileprivate func handleDownloadVideo(_ sender: UITapGestureRecognizer) {
        if let _ = downloadIndex {
            stopDownloadVideo()
        }
        findNewDownloadIndex(sender)
        startDownloadVideo()
    }
    
    fileprivate func stopDownloadVideo() {
        CommonOBJC.cancelAllDownloadFullRecord()
        anrDownloader.mpStopSdCard()
    }
    
    fileprivate func findNewDownloadIndex(_ sender: UITapGestureRecognizer) {
//        let location = sender.location(in: tblDataView)
//        guard let index = tblDataView.indexPathForRow(at: location) else {return}
//        downloadIndex = index.row
    }
    
    fileprivate func startDownloadVideo() {
//        if let obj = self.getCurrentItem() as? RecordPageModel {
//            guard let urlDownload = obj.file else {return}
//            downloadVideoFromCloud(urlDownload, nameVideoCloudDownload())
//        } else if let obj = self.getCurrentItem() as? RecordInfo{
//            anrDownloader.mpDownloadFileVi(obj)
//        }
    }
    
    fileprivate func nameVideoCloudDownload() -> String {
//        if let obj = self.getCurrentItem() as? RecordPageModel {
//            guard let cmrName = dataReceived?.cmrInfo?.name else {return ""}
//            guard let downloadAtTime = obj.recordtimestamp else {return ""}
//            let timeName = CommonOBJC.convertDateTimeFormaterToString(downloadAtTime, type: "ddMMyyyy HHmmss")
//            let viName = "\(cmrName)-\(timeName).mp4"
//            return viName
//        }
        return ""
    }
    
    fileprivate func downloadVideoFromCloud(_ urlStr: String, _ fileName: String) {
        let _ = CommonOBJC.downloadCloudFullRecordByUrl(urlStr, withName: fileName) { (isTrue, url) in
            if isTrue, let safeUrl = url {
                DispatchQueue.main.async {
                    self.handleWhenDownloadSuccess(safeUrl.path)
                }
            }
        } onProgess: { (progress) in }
    }
    
    fileprivate func handleWhenDownloadSuccess(_ path: String) {
        let urlFile = URL(fileURLWithPath: path)
        let activityVC = UIActivityViewController(activityItems: [urlFile], applicationActivities: [])
        activityVC.completionWithItemsHandler = {[weak self] activity, success, items, error in
            if success {
                self?.removeDownloadCache(path)
            }
            if let _ = activityVC.presentingViewController {
            } else {
                self?.removeDownloadCache(path)
            }
        }
        
        let vc = CommonOBJC.topViewController()
        vc?.present(activityVC, animated: true, completion: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.downloadIndex = nil
        }
    }

    fileprivate func removeDownloadCache(_ path : String) {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            do {
                try fileManager.removeItem(atPath: path)
            } catch let error as NSError{
                LogUtils.printLogError(error)
            }
        }
    }
    
    fileprivate func removeVideosDownloadedIfHadInCache() {
        deleteAllFilesDownloadedInCache(isVideoAnr: true)
        deleteAllFilesDownloadedInCache(isVideoAnr: false)
    }
    
    fileprivate func deleteAllFilesDownloadedInCache(isVideoAnr isAnr : Bool) {
        let name = isAnr ? "Video" : Common.FOLDER_DOWNLOAD_FULL_RECORD
        guard let mpPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(name) else {return}
        do {
            let anrUrls = try FileManager.default.contentsOfDirectory(at: mpPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for anrPath in anrUrls {
                if anrPath.pathExtension == "mp4" {
                    try FileManager.default.removeItem(at: anrPath)
                }
            }
        } catch let err {
            print(err)
        }
    }
     
    @objc fileprivate func handleAnrDownloadWhenAppBackground() {
        anrDownloader.mpStopSdCard()
        anrDownloadedPath = nil
        if let idx = downloadIndex {
            if let _ = arrAllVideoData[idx] as? RecordInfo {
                downloadIndex = nil
//                tblDataView.reloadData()
            }
        }
    }
    
    fileprivate var isAnrDownloading = false
    
    @objc fileprivate func checkAnrDownloadWhenAppBackground() {
        if isAnrDownloading {
            UIBaseViewController.showSnackbar(message: AppLanguage.fuRecMessageDownloadFailed,style: .white)
            isAnrDownloading = false
        }
    }
    
    //MARK:- Play/Stop  Video
    
    //TODO: Play Video When Table Cell Pressed
    
    fileprivate var timerStopVideo : Timer?
    
    fileprivate func handleWhenCellFocus(_ indexPath: IndexPath) {
//        if isPreparePlayAtFirstRow {isPreparePlayAtFirstRow = false}
//        fullRecView.mpStopPlayVideo()
//        handleWhenStopVideoImmediately()
//        isAnrIconTapped = false
//        playerSpinKit.isHidden = false
//
//        var timeWaiting : Double = 0
//        if let _ = self.getCurrentItem() as? RecordInfo {
//            fullRecSpinKit.isHidden = false
//            timeWaiting = 0.5
//        }
//        DispatchQueue.main.asyncAfter(deadline: .now() + timeWaiting) {
//            self.handlePlayVideo()
//        }
    }

    fileprivate func handlePlayVideo (_ newIndex : Int? = nil) {
        readyToPlay = false
        fullRecSpinKit.isHidden = true
        playerSpinKit.isHidden = false
        let index = newIndex ?? self.getCurrentItem()
        if arrAllVideoData.count > 0, let index = index {
            let date = self.convertToDate(arrAllVideoData[index])
            self.playingItem = (Int(date.0?.timeIntervalSince1970 ?? 0) , Int(date.1?.timeIntervalSince1970 ?? 0), index)
            if let obj = arrAllVideoData[index] as? RecordPageModel {
                isCloudPlaying = true
                handlePlayCloudFile(linkUrl: obj.file ?? "")
                let date = convertToDate(obj)
            } else {
                cmrOfflineView.isHidden = true
                cmrCantConnectView.isHidden = true
                
                timerStopVideo?.invalidate()
               
                timerStopVideo = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(anrQueryByTime), userInfo: nil, repeats: false)
                
            }
        } else {
            playerSpinKit.isHidden = true
            showHideViewNoData(isHidden: false)
        }
    }
    
    fileprivate func setupUiViewWhenCmrOffline() {
        [playerControlView, playBackImg, retryView].forEach{$0.isHidden = true}
        [backNavVi, cmrOfflineView].forEach{$0.isHidden = false}
        containerView.isUserInteractionEnabled = false
        playerSpinKit.isHidden = true
    }
    
    fileprivate func setupUiViewWhenCmrOnlineStart() {
        [backNavVi,playerControlView, cmrOfflineView, cmrCantConnectView].forEach{$0.isHidden = true}
        playBackImg.isHidden = false
        containerView.isUserInteractionEnabled = true
        
//        if let cell = tblDataView.cellForRow(at: IndexPath(row: currentIndex, section: 0)) as? FullRecordTblViCell {
//            cell.btnDownload.isHidden = !firstInfo.showDownloadIcon
//            if downloadIndex == currentIndex {
//                cell.btnDownload.isHidden = true
//            }
//        }
    }
    
    fileprivate func setupUiViewWhenCmrCantConnect() {
        cmrCantConnectView.isHidden = false
        playerSpinKit.isHidden = true
        playBackImg.isHidden = true
    }
    
    //TODO: Play Video From Cloud
    
    fileprivate var currentTimeCloudPlaying = 0
    fileprivate var isCloudPlaying: Bool?

    fileprivate func handlePlayCloudFile(linkUrl : String) {
        if linkUrl == "" {
            cmrOfflineView.isHidden = false
            return
        }
        fullRecView.isPause = false
        cmrOfflineView.isHidden = true
        fullRecView.mpPlayFullRecord(withLink: linkUrl)
        isCloudPlaying = true
    }
    
    //TODO: Play Video From SD Card
    
    fileprivate var timeStartPlaySdCard = 0
    fileprivate var timeEndPlaySdCard = 0
    fileprivate var timePlayingSdCard = 0
    
    @objc fileprivate func anrQueryByTime() {
        fromAnrQueryByTime = true
        apiCheckCmrOnOff()
    }
    
    fileprivate func handlePlayAnrFile() {
        if let index = self.getCurrentItem(), let obj = arrAllVideoData[index]  as? RecordInfo {
            fullRecView.anrVideoObj = obj
            isCloudPlaying = false
//            fullRecView.mpViPlaySdByTime()
            fullRecView.tpViPlaySd(Date(timeIntervalSince1970: TimeInterval(max(self.playingItem.0, self.rulerControl.currentValue))), to: Date(timeIntervalSince1970: TimeInterval(self.playingItem.1)), fname: obj.fileName)
        }
    }
    
    //TODO: Handle When Video Stop
    
    fileprivate func handleWhenStopVideoImmediately() {
        timeStartPlaySdCard = 0
        timeEndPlaySdCard = 0
        timePlayingSdCard = 0
        previousTimePlayingSdCard = 0
        anrRetryCounter = 0
        listenAnrPlaying = false
        timerForListenAnrPlaying?.invalidate()
        
        currentTimeCloudPlaying = 0
        isCloudPlaying = nil
        fullRecView.isPause = true
        playerControlView.updateBottomUI(currentValue: 0)
        
        retryView.isHidden = true
        playerSpinKit.isHidden = true
    }
    
    fileprivate func handleWhenVideoInTheEnd() {
        handleWhenStopVideoImmediately()
        playerControlView.setPlayButtonImage(true)
        switchBtnHandle()
//        tblDataView.scrollToRow(at: IndexPath(row: self.currentIndex, section: 0), at: .middle, animated: true)
    }
    
    //TODO: Check Anr Playing With Connect Unstable
    
    fileprivate var timerForListenAnrPlaying : Timer?
    fileprivate let retryView = RetryView()
    fileprivate var previousTimePlayingSdCard = 0
    fileprivate var anrRetryCounter = 0
    
    fileprivate var listenAnrPlaying = false {
        didSet {
            if listenAnrPlaying {
                checkAnrVideoConnectStable()
            }
        }
    }
    
    fileprivate func checkAnrVideoConnectStable() {
        if timeEndPlaySdCard != 0 {
            previousTimePlayingSdCard = timePlayingSdCard
            timerForListenAnrPlaying?.invalidate()
            timerForListenAnrPlaying = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(continueCheckAnrPlaying), userInfo: nil, repeats: false)
        }
    }
    
    @objc fileprivate func continueCheckAnrPlaying() {
        if previousTimePlayingSdCard != timePlayingSdCard {
            checkAnrVideoConnectStable()
        } else {
            listenAnrPlaying = false
            handleRetryPlayAnrLostConnect()
        }
    }
    
    @objc fileprivate func handleRetryPlayAnrLostConnect() {
        [retryView, backNavVi].forEach{$0.isHidden = false}
        [playerSpinKit, playerControlView].forEach{$0.isHidden = true}
        
        if anrRetryCounter < 3 {
            timerForListenAnrPlaying = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(fuRecShowSpinkit), userInfo: nil, repeats: false)
        }
    }

    @objc fileprivate func fuRecShowSpinkit() {
        retryView.isHidden = true
        playerSpinKit.isHidden = false
        anrRetryCounter += 1
        fullRecView.mpSdCardSeek(previousTimePlayingSdCard)
        previousTimePlayingSdCard = -1
        timerForListenAnrPlaying?.invalidate()
        timerForListenAnrPlaying = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(changeListenAnrPlayingValue), userInfo: nil, repeats: false)
    }
    
    @objc func changeListenAnrPlayingValue() {
        listenAnrPlaying = true
    }
    
    //TODO: api check cmr status
    
    fileprivate var fromAnrQueryByTime = false
    fileprivate var fromHandleAnrIconTapped = false
    fileprivate var apiCmrOnline: Bool? {
        didSet {
            guard let isCmrOnline = apiCmrOnline else {return}
            if fromAnrQueryByTime {
                if isCmrOnline {
                    if let obj = arrAllVideoData[self.playingItem.2]  as? RecordInfo {
                        mpConfig.anrObj = obj
                        mpConfig.mpGetSdByTime()
                    }
                } else {
                    setupUiViewWhenCmrOffline()
                }
                fromAnrQueryByTime = false
            } else if fromHandleAnrIconTapped {
                let _ = isCmrOnline ? (isAnrIconTapped = true) : addAnrBackdrop(anrBackdropInfo)
                fromHandleAnrIconTapped = false
            }
            apiCmrOnline = nil
        }
    }
    
}


//MARK:- Conform to Protocol

extension CMRFullRecordWithRulerViewController : MPplayerLocalViDelegate {
    func startPlayVideoTimeResult(_ startTime: Int, time: Int, timeRight: String, firstParam: Int) {
        DispatchQueue.main.async {
            self.playerControlView.setPlayButtonImage(false)
            self.setupUiViewWhenCmrOnlineStart()
        }
        if stateSpeaker {
            fullRecView.openSound(100)
        }
    }
    
    
    func startPlayVideoInfoResult(_ playTime: Int, stopTime: Int, timeLeft: String, timeRight: String) {
        if !readyToPlay {
            self.readyToPlay = true
            let time = self.rulerControl.currentValue - self.playingItem.0
            self.handleSlideTouchDown()
            self.seekVideoToTime(max(0,time), 0)
            return
        }
        if let cloudPlay = isCloudPlaying, cloudPlay {
            DispatchQueue.main.async {
                if self.listenAnrPlaying {
                    self.timerForListenAnrPlaying?.invalidate()
                    self.listenAnrPlaying = false
                    
                }
                self.currentTimeCloudPlaying = playTime
                if self.playerSpinKit.isHidden == false {
                    
                    self.playerSpinKit.isHidden = true
                    if self.playerControlView.isHidden == false {
                        self.backNavVi.isHidden = false
                    }
                    
                }
                self.playerControlView.updateBottomUI(maxValue: stopTime, currentValue: playTime, timeLeftStr: timeLeft, timrRightStr: timeRight)
                self.rulerControl.scrollToValue(playTime + Int(self.playingItem.0), animated: false)
            }
        }
    }
    
    func mpViResultPlaySdCard(_ paraStart: Int, withPlay paraPlay: Int, withEnd paraEnd: Int, playTime: Int, stopTime: Int, timeLeft: String, timeRight: String) {
//        if !readyToPlay {
//            self.readyToPlay = true
//            let time = self.rulerControl.currentValue - self.playingItem.0
//            self.handleSlideTouchDown()
//            self.seekVideoToTime(max(0,time), 0)
//            return
//        }
        if let cloudPlay = isCloudPlaying, !cloudPlay {
            
            DispatchQueue.main.async {
                if self.timeStartPlaySdCard == 0 {
                    self.timeStartPlaySdCard = paraStart
                }
                if self.timeEndPlaySdCard == 0 {
                    self.timeEndPlaySdCard = paraEnd
                    self.listenAnrPlaying = true
                }
                self.timePlayingSdCard = paraPlay
                
                if self.playerSpinKit.isHidden == false {
                    self.playerSpinKit.isHidden = true
                    self.retryView.isHidden = true

                    if self.playerControlView.isHidden == false {
                        self.backNavVi.isHidden = false
                    }
                }
                
                if self.anrRetryCounter != 0 {
                    self.anrRetryCounter = 0
                }

                self.playerControlView.updateBottomUI(maxValue: stopTime, currentValue: playTime, timeLeftStr: timeLeft, timrRightStr: timeRight)
                self.rulerControl.scrollToValue(paraPlay, animated: false)
            }
        }
    }

    func stopPlayVideoResult() {
        DispatchQueue.main.async {
            self.handleWhenVideoInTheEnd()
        }
    }
    
    func errorNoDataForLongTime(withParam param1: Int32, withParam2 param2: Int32, withParam3 param3: Int32) {
        print(param1)
    }
}

extension CMRFullRecordWithRulerViewController : MPvideoFileConfigDelegate {
    func mpGetVideoResult(_ result: Int, withRecord arrayFile: NSMutableArray) {
        self.receivedAnrByFileResult = true
        if result >= 0 {
            DispatchQueue.main.async {
                guard let arr = arrayFile as? [RecordInfo] else {return}
                if self.firstInfo.method != self.sdMethodTxt {
                    self.mpVideoAnrArray = arr
                }else {
                    self.arrAllVideoData = self.firstInfo.isDecreasing ? arr.reversed() : arr
                    self.arrAllVideoDataUpdateFinished()
                    self.initLoadingView.isHidden = true
                }
            }
        } else {
            DispatchQueue.main.async {
                if self.firstInfo.method != self.sdMethodTxt {
                    guard let arrSer = self.arrVideoFromServer, let idx = self.tempIdxAnrQuery else {return}
                    var arr = Array(arrSer[idx ..< arrSer.count])
                    arr.removeAll{$0.is_anr == true}
                    self.arrAllVideoData += arr
                }

                if self.arrAllVideoData.count > 0 {
                    self.arrAllVideoDataUpdateFinished()
                } else {
                    self.showHideViewNoData(isHidden: false)
                    self.tempIdxAnrQuery = nil
                }
            }
        }
    }
    
    func mpResultGetVi(byTime result: Int) {
        self.resultAnrByTime = result
        if result >= 0 {
            DispatchQueue.main.async {
                self.handlePlayAnrFile()
            }
        } else {
            DispatchQueue.main.async {
                if result == -10005 {
                    self.setupUiViewWhenCmrOffline()
                } else {
                    self.setupUiViewWhenCmrCantConnect()
                }
            }
        }
    }
}

extension CMRFullRecordWithRulerViewController : MPViFileDownloadDelegate {
    func mpResultFileStartDownload(_ result: Int) {
        if result < 0 {
            DispatchQueue.main.async {
                self.downloadIndex = nil
                UIBaseViewController.showSnackbar(message: AppLanguage.fuRecMessageDownloadFailed,style: .white)
//                self.tblDataView.reloadData()
            }
        } else {
            DispatchQueue.main.async {
                self.isAnrDownloading = true
                UIBaseViewController.showSnackbar(message: AppLanguage.fuRecMessageDownloading,style: .white)
            }
        }
    }
    
    func mpResultFileDownloadProgress(_ progress: Float) {}
    
    func mpResultFileEndDownload(_ anrDownloadedPathStr: String) {
        DispatchQueue.main.async {
            self.isAnrDownloading = false
            self.anrDownloadedPath = anrDownloadedPathStr
        }
    }
}

extension CMRFullRecordWithRulerViewController : ISCCameraDeviceManagerDelegate {
    func addDeviceResult(_ sId: String, result: Int32, seq: Int32) {
        cmrDeviceManager.getDeviceChannel(dataReceived?.cmrInfo?.serial ?? "", seq: seq)
    }
    
    func getDeviceChannel(_ sId: String, result: Int32, seq: Int32) {
        if result > 0 {
            cmrDeviceManager.cleanSelectChannel()
            let obj = cmrDeviceManager.getDeviceObject(bySN: sId)
            cmrDeviceManager.setSelectChannel(obj?.channelArray?.firstObject as! ChannelObject)
            DispatchQueue.main.async {
                self.handleWhenReceivedLoginCmrDeviceResult(true)
            }
        } else {
            DispatchQueue.main.async {
                self.handleWhenReceivedLoginCmrDeviceResult(false)
            }
        }
    }
}

extension CMRFullRecordWithRulerViewController : UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return fullRecView
    }
}

//MARK:- Use API To Get and Handle Data From Server

extension CMRFullRecordWithRulerViewController {

    fileprivate func getArrVideoFromServer(_ atDate: FullRecDateModel, _ pageNumber: String) {
        guard let data = dataReceived else {return}
        
        if currentPageLoad == 1 {
            initLoadingView.isHidden = false
        } else {
            fullRecSpinKit.isHidden = false
        }
        
        let request = FullRecordInputModel(serial: data.serial, start_time: Common.shared.convertFromDateToString(atDate.startDate), stop_time: Common.shared.convertFromDateToString(atDate.endDate), page_number: pageNumber)
        
        getDataFromServer(request) { [weak self] (response) in
            self?.fullRecSpinKit.isHidden = true
            self?.initLoadingView.isHidden = true
            if response.result {
                guard let safeData = response.data else {return}
                switch safeData.count  {
                case 0:
                    _ = self?.currentPageLoad == 1 ? self?.showHideViewNoData(isHidden: false) : ()
                default:
                    self?.totalPageMustLoad = safeData[0].page_total
                    self?.currentPageLoad = safeData[0].current_page
                    self?.isAnrReversed = safeData[0].is_decreasing
                    
                    guard let recordPage = safeData[0].record_page, !recordPage.isEmpty else {return}
                    DispatchQueue.main.async {
                        self?.arrVideoFromServer = recordPage
                    }
                    
                    if self?.currentPageLoad == 1 {
                        self?.showHideViewNoData(isHidden: true)
                    }
                }
            }
        } _: {[weak self] (error) in
            guard let self = self else {return}
            self.fullRecSpinKit.isHidden = true
            self.initLoadingView.isHidden = true
            self.showHideViewNoData(isHidden: self.currentPageLoad != 1)
            self.handleError(title: AppLanguage.commonAppName, error: error)
        }
    }
    
    fileprivate func apiCheckCmrOnOff() {
        guard let info = dataReceived?.cmrInfo else {return}
        let input = FullRecCheckCmrStatusInput(list_serial: [info.serial ?? ""])
        checkCmrStatus(input) { [weak self] (response) in
            if response.result {
                guard let data = response.data, !data.isEmpty else {return}
                DispatchQueue.main.async {
                    self?.apiCmrOnline = data[0].status == 0 ? false : true
                }
            } else {
                self?.alertMessageOk(title: AppLanguage.commonAppName, message: response.message)
            }
        } _: { [weak self] (error) in
            self?.handleError(title: AppLanguage.commonAppName, error: error)
        }
    }
 
    func showHideViewNoData(isHidden:Bool){
//        [noDataView,lblNodata].forEach{$0.isHidden = isHidden}
        playerControlView.isHidden = !isHidden
        initLoadingView.isHidden = true
    }

}

//MARK:- Utility Methods

extension CMRFullRecordWithRulerViewController {

    fileprivate func extractHmFromDate(_ date: String?) -> String {
        guard let dateStr = date else {return ""}
        return Common.shared.convertDateTimeFormaterToString(dateStr, type: "HH:mm:ss")
    }
    
    fileprivate func setDateTimeRange(stDate: MPdate, enDate: MPdate) -> FullRecDateModel? {
        let stDate = initDateTime(stDate.h, stDate.m, sec: stDate.s, date: stDate.mpDate)
        let etDate = initDateTime(enDate.h, enDate.m, sec: enDate.s, date: enDate.mpDate)
        guard let st = stDate, let et = etDate else {return nil}
        let dateModel = FullRecDateModel(startDate: st, endDate: et)
        return dateModel
    }
    
    fileprivate func initDateTime(_ hours: Int, _ min: Int, sec: Int, date: Date) -> Date? {
        let dateTime = Calendar.appCalendar.date(bySettingHour: hours, minute: min, second: sec, of: date)
        return dateTime
    }
    
    fileprivate func stringDateToTimeModel(_ date: String) -> MPdate? {
        let fmt = DateFormatter()
        fmt.calendar = .appCalendar
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let dateObj = fmt.date(from: date) else {return nil}
        fmt.dateFormat = "HH"
        guard let hour = Int(fmt.string(from: dateObj)) else {return nil}
        fmt.dateFormat = "mm"
        guard let minute = Int(fmt.string(from: dateObj)) else {return nil}
        fmt.dateFormat = "ss"
        guard let sec = Int(fmt.string(from: dateObj)) else {return nil}
        return MPdate(mpDate: dateObj ,h: hour, m: minute, s: sec)
    }
    
    fileprivate func intToStr(_ i: Int32)-> String {
        if i < 10 { return "0\(i)" }
        return "\(i)"
    }
    
}
extension CMRFullRecordWithRulerViewController : TPRulerPickerDataSource, TPRulerPickerDelegate {
    func rulerPicker(_ picker: TPRulerPicker, titleForIndex index: Int, value: Int) -> String? {
        guard index % picker.configuration.metrics.divisions == 0 else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(index * picker.configuration.metrics.valueSpacing + picker.configuration.metrics.minimumValue))
        return (date.day == 0 && date.month == 0) ? "\(date.toString("dd/MM"))" : "\(date.toString("HH:mm"))"
    }
    
    func rulerPicker(_ picker: TPRulerPicker, valueChangeForIndex index: Int, value: Int) {
        indicatorLabel.text = "\(Date(timeIntervalSince1970: TimeInterval(value)).toString("dd/MM HH:mm:ss"))"
        infoView.detailDateLbl.text = "\(Date(timeIntervalSince1970: TimeInterval(value)).toString("dd/MM/yyyy"))"
    }
    func rulerPicker(_ picker: TPRulerPicker, didSelectItemAtIndex index: Int, value: Int) {
        self.handlePlayVideo()
    }
    
    func rulerPicker(_ picker: TPRulerPicker, ViewWillBeginDragging index: Int, value: Int) {
        playerControlView.setPlayButtonImage(true)
        if !fullRecView.isPause { fullRecView.pauseOrResumePlay() }
        fullRecView.mpStopPlayVideo()
        fullRecView.dismissPlayView()
    }
    
    func rulerPicker(_ picker: TPRulerPicker, willDisplayForValue value: Int) {
        if firstInfo.method == sdMethodTxt || !(arrAllVideoData.count - 3 > 0) {return}
        let date = convertToDate(arrAllVideoData[arrAllVideoData.count - 1 - 3])
        let lastTime = Int(date.1?.timeIntervalSince1970 ?? 0)
        let isLoadmore = (value < lastTime && value > lastTime - (20 * 60)) && (currentPageLoad < totalPageMustLoad!) && isArrAllVideoUpdateFinished
        if isLoadmore {
            isArrAllVideoUpdateFinished = false
            currentPageLoad += 1
            getArrVideoFromServer(datePlayVideo!, "\(currentPageLoad)")
        }
    }
}
    
