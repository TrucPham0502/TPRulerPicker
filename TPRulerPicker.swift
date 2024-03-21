//
//  TPRulerPicker.swift
//  
//
//  Created by TrucPham on 02/06/2023.
// 
//

import Foundation
import UIKit

protocol TPRulerPickerDataSource: AnyObject {
    func rulerPicker(_ picker: TPRulerPicker, titleForIndex index: Int, value : Int) -> String?
    func rulerPicker(_ picker: TPRulerPicker, valueChangeForIndex index: Int, value : Int)
    func rulerPicker(_ picker: TPRulerPicker, willDisplayForValue value: Int)
}

protocol TPRulerPickerDelegate: AnyObject {
    func rulerPicker(_ picker: TPRulerPicker, didSelectItemAtIndex index: Int, value : Int)
    func rulerPicker(_ picker: TPRulerPicker, ViewWillBeginDragging index: Int, value : Int)
}

struct TPRulerPickerConfiguration {
    
    enum Direction {
        case horizontal, vertical
    }
    
    enum Alignment {
        case start, end
    }
    
    struct Metrics {
        var valueSpacing : Int = 1
        var minimumValue: Int = 10
        var defaultValue: Int = 55 {
            didSet {
                defaultValue = max(maximumValue, min(defaultValue, minimumValue))
            }
        }
        var maximumValue: Int = 150
        var divisions = 10
        
        var fullLineSize: CGFloat = 40
        var midLineSize: CGFloat = 28
        var smallLineSize: CGFloat = 18
        var indicatorLineSize: CGFloat = 40
        
        var midDivision: Int {
            divisions / 2
        }
        
        init(minimumValue: Int = 10, defaultValue: Int = 55, maximumValue: Int = 150, valueSpacing: Int = 1, divisions: Int = 10, fullLineSize: CGFloat = 40, midLineSize: CGFloat = 28, smallLineSize: CGFloat = 18, indicatorLineSize : CGFloat = 40) {
            self.minimumValue = minimumValue
            self.defaultValue = defaultValue
            self.maximumValue = maximumValue
            self.divisions = divisions
            self.fullLineSize = fullLineSize
            self.midLineSize = midLineSize
            self.smallLineSize = smallLineSize
            self.valueSpacing = valueSpacing
            self.indicatorLineSize = indicatorLineSize
        }
        
        func value(for type: LineHeight) -> CGFloat {
            switch type {
            case .full: return fullLineSize
            case .mid: return midLineSize
            case .small: return smallLineSize
            }
        }
        
        func lineType(index: Int) -> LineHeight {
            if index % divisions == 0 {
                return .full
            } else if index % midDivision == 0 {
                return .mid
            } else {
                return .small
            }
        }
        
        static var `default`: Metrics { Metrics() }
        
        //        static var inches: Metrics {
        //            Metrics(divisions: 12)
        //        }
    }
    
    var scrollDirection: Direction = .horizontal
    var alignment: Alignment = .end
    var lineSpacing: CGFloat = 10
    var lineAndLabelSpacing: CGFloat = 6
    var metrics: Metrics = .default
    /// Enabling Haptic Feedbacks to Supporting devices. Default value is `true`.
    var isHapticsEnabled: Bool = true
    
    static var `default`: TPRulerPickerConfiguration { TPRulerPickerConfiguration() }
    
    init(scrollDirection: TPRulerPickerConfiguration.Direction = .horizontal, alignment: TPRulerPickerConfiguration.Alignment = .end, lineSpacing: CGFloat = 10, lineAndLabelSpacing: CGFloat = 6, metrics: TPRulerPickerConfiguration.Metrics = .default, isHapticsEnabled: Bool = true) {
        self.scrollDirection = scrollDirection
        self.alignment = alignment
        self.lineSpacing = lineSpacing
        self.lineAndLabelSpacing = lineAndLabelSpacing
        self.metrics = metrics
        self.isHapticsEnabled = isHapticsEnabled
    }
    
    
    fileprivate var isHorizontal: Bool {
        scrollDirection == .horizontal
    }
}

enum LineHeight {
    case full, mid, small
    
    init(index: Int, divisions: Int, midDivision: Int) {
        if index % divisions == 0 {
            self = .full
        } else if index % midDivision == 0 {
            self = .mid
        } else {
            self = .small
        }
    }
}

class TPRulerPicker: UIView {
    
    // MARK: -  properties
    private var spacingOffsetAndInset: CGFloat = 0
    var dataColors : [(point: [(from: Int, to: Int)], color: UIColor)] = [] {
        didSet {
            drawBackground()
        }
    }
    var configuration: TPRulerPickerConfiguration = .default {
        didSet {
            configureCollectionView()
        }
    }
    
    var font: UIFont = .systemFont(ofSize: 12)
    
    
    var highlightLineColor: UIColor = .black {
        didSet {
            indicatorLine.backgroundColor = highlightLineColor
            indicatorTriangle.fillColor = highlightLineColor.cgColor
        }
    }
    var contentBackground : UIColor = .clear {
        didSet {
            self.backgroundLayer.backgroundColor = contentBackground.cgColor
        }
    }
    
    private let indicatorTriangle = CAShapeLayer()
    weak var dataSource: TPRulerPickerDataSource?
    
    weak var delegate: TPRulerPickerDelegate?
    
    var highlightedIndex: Int = 0
    
    // MARK: - UI Elements
    let backgroundLayer = CAShapeLayer()
    private lazy var collectionView: UICollectionView = {
        $0.backgroundColor = .clear
        $0.showsHorizontalScrollIndicator = false
        $0.showsVerticalScrollIndicator = false
        //        $0.delegate = self
        //        $0.dataSource = self
        $0.contentOffset = .zero
        backgroundLayer.zPosition = -1
        $0.layer.insertSublayer(backgroundLayer, at: 0)
        return $0
    }(UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout()))
    
    
    private lazy var indicatorLine: UIView = {
        let v = UIView()
        v.backgroundColor = highlightLineColor
        let triangleSize : CGFloat = 5
        let b = UIBezierPath()
        b.move(to: .init(x: -triangleSize - (self.itemSize.width / 2), y: 0))
        b.addLine(to: .init(x: triangleSize + (self.itemSize.width / 2), y: 0))
        b.addLine(to: .init(x: (self.itemSize.width / 2), y: triangleSize))
        b.fill()
        b.close()
        indicatorTriangle.path = b.cgPath
        indicatorTriangle.fillColor = highlightLineColor.cgColor
        v.clipsToBounds = false
        v.layer.addSublayer(indicatorTriangle)
        return v
    }()
    
    private var layout: UICollectionViewFlowLayout {
        collectionView.collectionViewLayout as! UICollectionViewFlowLayout
    }
    
    private var itemSize: CGSize = CGSize(width: 1, height: 1)
    
    private var cellWidthIncludingSpacing: CGFloat {
        if configuration.isHorizontal {
            return itemSize.width + self.layout.minimumLineSpacing
        } else {
            return itemSize.height + self.layout.minimumInteritemSpacing
        }
    }
    
    var valueOffset : CGFloat {
        let offset = collectionView.contentOffset
        let contentInset = collectionView.contentInset
        let itemsCount = collectionView.numberOfItems(inSection: 0) - 1
        if configuration.isHorizontal {
            let roundedIndex = ((offset.x - spacingOffsetAndInset) + contentInset.left) / cellWidthIncludingSpacing
            return max(0, min(CGFloat(itemsCount), roundedIndex))
        } else {
            let roundedIndex = (offset.y + contentInset.top) / cellWidthIncludingSpacing
            return max(0, min(CGFloat(itemsCount), roundedIndex))
        }
    }
    var currentValue : Int {
        let extend = Int(round((valueOffset) * Double(configuration.metrics.valueSpacing))) + configuration.metrics.minimumValue
        return extend
    }
    
    @available(iOS 10.0, *)
    lazy var feedbackGenerator : UISelectionFeedbackGenerator? = nil
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.masksToBounds = true
        // lech content offset va content inset
        if spacingOffsetAndInset == 0, collectionView.contentInset.left > 0, collectionView.contentOffset.x < 0 {
            spacingOffsetAndInset = abs(collectionView.contentInset.left + collectionView.contentOffset.x)
        }
        
        if configuration.isHorizontal {
            collectionView.contentInset = UIEdgeInsets(top: 0, left: bounds.midX, bottom: 0, right: bounds.midX)
            indicatorLine.center.x = collectionView.center.x
            indicatorLine.frame.size = CGSize(width: self.itemSize.width, height: configuration.metrics.indicatorLineSize)
            switch configuration.alignment {
            case .start:
                indicatorLine.frame.origin.y = 0
            case .end:
                indicatorLine.frame.origin.y = bounds.height - indicatorLine.frame.size.height
            }
            
        } else {
            collectionView.contentInset = UIEdgeInsets(top: bounds.midY, left: 0, bottom: bounds.midY, right: 0)
            indicatorLine.center.y = collectionView.center.y
            indicatorLine.frame.size = CGSize(width: configuration.metrics.indicatorLineSize, height: self.itemSize.width)
            switch configuration.alignment {
            case .start:
                indicatorLine.frame.origin.x = 0
            case .end:
                indicatorLine.frame.origin.x =  configuration.metrics.indicatorLineSize + configuration.lineAndLabelSpacing
                
            }
        }
    }
    private func drawBackground(){
        let size : CGRect
        if  configuration.isHorizontal {
            size = .init(origin: .zero, size: .init(width:  (CGFloat(self.collectionView.numberOfItems(inSection: 0)) * cellWidthIncludingSpacing) - self.layout.minimumLineSpacing, height: self.frame.height))
        }
        else {
            size = .init(origin: .zero, size: .init(width: self.frame.width, height:  (CGFloat(self.collectionView.numberOfItems(inSection: 0)) * cellWidthIncludingSpacing) - self.layout.minimumInteritemSpacing))
        }
        backgroundLayer.frame = size
        backgroundLayer.masksToBounds = true
        backgroundLayer.sublayers?.forEach({ $0.removeFromSuperlayer() })
        let backgroundSize = backgroundLayer.frame.size
        let widthSecond = backgroundSize.width / (CGFloat((configuration.metrics.maximumValue) - (configuration.metrics.minimumValue)))
        let subs = dataColors.flatMap { sub in
            var res : [CAShapeLayer] = []
            let layer = CAShapeLayer()
            let bezier = UIBezierPath()
            let beziers = sub.point.map { (from: Int, to: Int) in
                let bezier = UIBezierPath(roundedRect: CGRect(origin: .init(x: CGFloat(from - (configuration.metrics.minimumValue)) * widthSecond, y: 0.0), size: .init(width: CGFloat(to - from) * widthSecond, height: backgroundSize.height)), cornerRadius: 0)
                return bezier
            }
            beziers.forEach(bezier.append(_:))
            layer.fillColor = sub.color.cgColor
            layer.path = bezier.cgPath
            res.append(layer)
            return res
        }
        subs.forEach(self.backgroundLayer.addSublayer)
        backgroundLayer.backgroundColor = contentBackground.cgColor
    }
    
    private func commonInit() {
        addSubview(collectionView)
        addSubview(indicatorLine)
        collectionView.register(TPRulerLineCell.self, forCellWithReuseIdentifier: TPRulerLineCell.identifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: collectionView.superview!.topAnchor),
            collectionView.leftAnchor.constraint(equalTo: collectionView.superview!.leftAnchor),
            collectionView.bottomAnchor.constraint(equalTo: collectionView.superview!.bottomAnchor),
            collectionView.rightAnchor.constraint(equalTo: collectionView.superview!.rightAnchor),
        ])
        configureCollectionView()
    }
    
    func reloadData() {
        collectionView.reloadData()
    }
    
    // MARK: - Config
    
    private func configureCollectionView() {
        layout.minimumLineSpacing = configuration.lineSpacing
        layout.minimumInteritemSpacing = configuration.lineSpacing
        if configuration.isHorizontal {
            layout.scrollDirection = .horizontal
            //            layout.itemSize = CGSize(width: 1, height: bounds.height)
        } else {
            layout.scrollDirection = .vertical
            //            layout.itemSize = CGSize(width: bounds.width, height: 1)
        }
        scrollToValue(configuration.metrics.defaultValue, animated: false)
    }
    
    func scrollToValue(_ value: Int, animated: Bool = true) {
        //        setNeedsLayout()
        //        layoutIfNeeded()
        layoutSubviews()
        collectionView.reloadData()
        collectionView.layoutSubviews()
        let offset: CGPoint
        let selected = CGFloat(value - configuration.metrics.minimumValue) / CGFloat(configuration.metrics.valueSpacing)
        if configuration.isHorizontal {
            offset = CGPoint(x: selected * cellWidthIncludingSpacing - collectionView.contentInset.left, y: 0)
        } else {
            offset = CGPoint(x: 0, y: selected * cellWidthIncludingSpacing - collectionView.contentInset.top)
        }
        
        DispatchQueue.main.async {
            self.collectionView.setContentOffset(offset, animated: animated)
            self.dataSource?.rulerPicker(self, valueChangeForIndex: Int(self.valueOffset), value: value)
        }
    }
}

extension TPRulerPicker: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        Int(configuration.metrics.maximumValue / configuration.metrics.valueSpacing) - Int(configuration.metrics.minimumValue / configuration.metrics.valueSpacing) + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TPRulerLineCell.identifier, for: indexPath) as! TPRulerLineCell // swiftlint:disable:this force_cast
        cell.tintColor = tintColor
        cell.numberLabel.font = font
        
        cell.numberLabel.text = dataSource?.rulerPicker(self, titleForIndex: indexPath.item, value: self.currentValue)
        cell.configure(indexPath.row, using: configuration)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let extend = Int(round(Double(indexPath.item) * Double(configuration.metrics.valueSpacing))) + configuration.metrics.minimumValue
        self.dataSource?.rulerPicker(self, willDisplayForValue: extend)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if configuration.isHorizontal {
            itemSize = CGSize(width: 1, height: bounds.height)
        } else {
            itemSize = CGSize(width: bounds.width, height: 1)
        }
        return itemSize
    }
}

extension TPRulerPicker: UIScrollViewDelegate {
    //     func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    //
    //        var offset = targetContentOffset.pointee
    //        let contentInset = scrollView.contentInset
    //
    //        if configuration.isHorizontal {
    //            let roundedIndex = round((offset.x + contentInset.left) / cellWidthIncludingSpacing)
    //            offset = CGPoint(x: roundedIndex * cellWidthIncludingSpacing - contentInset.left, y: -contentInset.top)
    //        } else {
    //            let roundedIndex = round((offset.y + contentInset.top) / cellWidthIncludingSpacing)
    //            offset = CGPoint(x: -contentInset.left, y: roundedIndex * cellWidthIncludingSpacing - contentInset.top)
    //        }
    //
    //        targetContentOffset.pointee = offset
    //    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if #available(iOS 10.0, *), configuration.isHapticsEnabled {
            feedbackGenerator = UISelectionFeedbackGenerator()
            feedbackGenerator?.prepare()
        }
        delegate?.rulerPicker(self, ViewWillBeginDragging: Int(valueOffset), value: self.currentValue)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { endScroll() }
    }
    
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let index = Int(valueOffset)
        if highlightedIndex != index {
            if #available(iOS 10.0, *), configuration.isHapticsEnabled {
                feedbackGenerator?.selectionChanged()
                feedbackGenerator?.prepare()
            }
        }
        highlightedIndex = index
        self.dataSource?.rulerPicker(self, valueChangeForIndex: index, value: self.currentValue)
    }
    
    func endScroll(){
        delegate?.rulerPicker(self, didSelectItemAtIndex: Int(valueOffset), value: self.currentValue)
        if #available(iOS 10.0, *) {
            feedbackGenerator = nil
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        endScroll()
    }
    
}

private class TPRulerLineCell: UICollectionViewCell {
    
    static let identifier = String(describing: TPRulerLineCell.self)
    
    fileprivate lazy var lineView: UIView = {
        let view = UIView()
        view.backgroundColor = tintColor
        return view
    }()
    
    fileprivate lazy var numberLabel: UILabel = {
        $0.textColor = tintColor
        $0.textAlignment = .center
        return $0
    }(UILabel())
    
    override var tintColor: UIColor! {
        didSet {
            numberLabel.textColor = tintColor
            lineView.backgroundColor = tintColor
        }
    }
    
    var lineHeight: LineHeight = .full
    
    var config: TPRulerPickerConfiguration = .default
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        clipsToBounds = false
        
        addSubview(lineView)
        addSubview(numberLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        //        super.init(coder: aDecoder)
        fatalError()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
    }
    
    private func updateHeight(for type: LineHeight, config: TPRulerPickerConfiguration) {
        var origin: CGPoint
        var size: CGSize
        size = .init(width: bounds.width, height: config.metrics.value(for: type))
        switch config.alignment {
        case .start:
            origin = .zero
        case .end:
            origin = .init(x: 0, y: bounds.height - size.height)
        }
        if !config.isHorizontal {
            origin = .zero
            size = .init(width: config.metrics.value(for: type), height: bounds.height)
        }
        lineView.frame = .init(origin: origin, size: size)
    }
    
    func configure(_ index: Int, using config: TPRulerPickerConfiguration) {
        lineHeight = LineHeight(index: index, divisions: config.metrics.divisions, midDivision: config.metrics.midDivision)
        updateHeight(for: lineHeight, config: config)
        
        numberLabel.sizeToFit()
        
        if config.isHorizontal {
            numberLabel.center.x = lineView.center.x
            switch config.alignment {
            case .start:
                numberLabel.frame.origin.y = lineView.frame.origin.y + lineView.frame.size.height + config.lineAndLabelSpacing
            case .end:
                numberLabel.frame.origin.y = bounds.height - lineView.frame.size.height - config.lineAndLabelSpacing - numberLabel.frame.size.height
            }
        } else {
            numberLabel.center.y = lineView.center.y
            numberLabel.frame.origin.x = config.metrics.fullLineSize + config.lineAndLabelSpacing
        }
    }
}


