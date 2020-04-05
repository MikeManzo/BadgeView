//
//  BadgeView.swift
//  BadgeView
//
//  Created by Mike Manzo on 03/22/20.
//  Copyright © 2020 Mike Manzo. All rights reserved.
//
//
//  BadgeView.swift
//
//  Based on original work by Aral Balkan
//

import AppKit
import Cartography

protocol CustomTaggable {
    var customTag:Int {get set}
}

@IBDesignable
open class BadgeView: NSView, CustomTaggable {
    // Make sure it works with vibrant views.
    public override var allowsVibrancy: Bool { return true }
    
    var _nibName: String?
    @IBInspectable
    var XibName: String = "__CHANGE ME__" {
        willSet {
            needsDisplay = true
            _nibName = newValue
            commonInit()
        }
    }
    
    //
    // MARK: - Public API
    //
    
    // No upper limit.
    public func incrementCounter() {
        count += 1
    }
        
    // Badges must always be positive or zero (at which point badge should be hidden)
    public func decrementCounter() {
        if count >= 1 {
            count -= 1
        }
    }
    
    //
    // MARK: - Properties
    //
    
    var lastCount:Int = 1
    var customCountStringToUseToCalculateIntrinsicContentSize:String? = nil
    
    @IBInspectable open var customTag:Int = -1
    
    @IBInspectable open var count:Int = 1 {
        didSet {
            // If the count was set to zero, show the last non-zero count so we can
            // animate the badge out on that value instead.
            label.stringValue = count == 0 ? "\(lastCount)" : "\(count)"
            
            invalidateIntrinsicContentSize()
            
            #if !TARGET_INTERFACE_BUILDER
            if lastCount == 0 && count > 0 {
                showBadgeWithAnimation()
            }
            else if self.count == 0 {
                hideBadgeWithAnimation()
            }
            else{
                updateBadgeWithAnimation()
            }
            #endif
        }
    }
    
    
    @IBInspectable open var fontColor:NSColor! {
        didSet {
            updateFont()
        }
    }
    
    @IBInspectable open var backgroundColor:NSColor! {
        didSet {
            needsDisplay = true
        }
    }
    
    @IBInspectable open var fontsizeBelowWhichLabelDisplaysInBoldface:CGFloat = 16.0 {
        didSet {
            updateFont()
        }
    }
    
    @IBInspectable open var fontSizeRelativeToBadge:CGFloat = 0.60 {
        didSet {
            updateFont()
        }
    }
    
    @IBInspectable open var horizontalPadding:CGFloat = 0.0 {
        didSet {
            needsDisplay = true
        }
    }
    
    enum Alignment {
        case topRight
        case topLeft
        case bottomRight
        case bottomLeft
    }
    let alignments = [Alignment.topRight, Alignment.topLeft, Alignment.bottomRight, Alignment.bottomLeft]
    let alignmentNames = ["top right", "top left", "bottom right", "bottom left"]
    
    var customView:NSView!
    var label:NSTextField!
    var customViewTopLevelObjects:NSArray?
    var timer:Timer?
    
    var constraintGroup:ConstraintGroup?
    
    /*@IBOutlet*/ var parentView:NSView?
    
    //
    // MARK: - Initialisation
    //
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    func commonInit() {
        // Load the view from the nib and grab a reference to the label text field.
        loadNib()
        label = viewWithTag(100) as? NSTextField
        
        #if !TARGET_INTERFACE_BUILDER
        
        // Our superview must be layer-backed so that our animations do not get clipped.
        // (e.g., the scale up bounce before the badge disappears)
        self.superview!.wantsLayer = true
        
        #endif
        
        // Make the custom view we loaded from the Nib match our dimensions.
        constrain(customView) {
            /* as */ customView in
            
            customView.width == customView.superview!.width
            customView.height == customView.superview!.height
        }
        
        // Default background color is red.
        backgroundColor = NSColor.red
        
        // Default font color is white.
        fontColor = NSColor.white
        
        // Default horizontal padding is the width of the letter M in the font.
        horizontalPadding = label.font!.widthOfString(string: "W")
        
        // Update the font
        updateFont()
        
        // Make the view layer-backed so that we can round the corners.
        self.wantsLayer = true
        self.layer?.masksToBounds = true
        
        // Default count
        count = 1
    }
    
    func updateFont() {
        // Size the font so there’s padding around it.
        let fontSize:CGFloat = self.frame.height * fontSizeRelativeToBadge

        // If smaller
        let font = fontSize < fontsizeBelowWhichLabelDisplaysInBoldface ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        
        label.font = font
        label.textColor = fontColor
    }

    public override func awakeFromNib() {
        #if !TARGET_INTERFACE_BUILDER
        //
        // Note:
        //
        // We cannot introspect prototyping constraints in NSViews like we can
        // in UIViews (please ask Apple to fix this by duplicating rdar://21887757 and
        // see http://openradar.appspot.com/radar?id=4815526492635136 for the full report).
        //
        // Because of this, you have to create at least one placeholder constraint on your
        // badge so that prototyping constraints do not get created. This is true even if you
        // don’t set the parentView outlet and take advantage of auto-alignment.
        //
        
        //
        // If a parent view has been set, align us to it.
        //
        if let parentView = parentView {
            let myCenterX = NSMidX(self.frame)
            let myCenterY = NSMidY(self.frame)
            let parentCenterX = NSMidX(parentView.frame)
            let parentCenterY = NSMidY(parentView.frame)
            
            let myOffsetX = self.frame.size.width / 2
            let myOffsetY = -1 * self.frame.size.height / 2
            
            let top:Int = 0b00, bottom:Int = 0b10, right:Int = 0b00, left:Int = 0b01
            var bitmask:Int = 0b0
            
            bitmask |= myCenterX < parentCenterX ? left : right
            bitmask |= myCenterY < parentCenterY ? bottom : top
            
            let alignmentToParent = alignments[bitmask]
            
            switch alignmentToParent {
            case Alignment.topRight:
                constraintGroup = constrain(self, parentView) {
                    /* as */ view, parentView in
                    
                    view.trailing == parentView.trailing + myOffsetX
                    view.top == parentView.top + myOffsetY
                }
            case Alignment.topLeft:
                constraintGroup = constrain(self, parentView) {
                    /* as */ view, parentView in
                    
                    view.leading == parentView.leading - myOffsetX
                    view.top == parentView.top + myOffsetY
                }
            case Alignment.bottomRight:
                constraintGroup = constrain(self, parentView) {
                    /* as */ view, parentView in
                    
                    view.trailing == parentView.trailing + myOffsetX
                    view.bottom == parentView.bottom - myOffsetY
                }
            case Alignment.bottomLeft:
                constraintGroup = constrain(self, parentView) {
                    /* as */ view, parentView in
                    
                    view.leading == parentView.leading - myOffsetX
                    view.bottom == parentView.bottom - myOffsetY
                }
            }
        }
        #endif
    }
    
    //
    // MARK: - Nib
    //
/*    func loadNib() {
        //
        // Load the nib for the component then find and add the view from it.
        //
        if (!Bundle(for: type(of: self)).loadNibNamed("BadgeView", owner: self, topLevelObjects: &customViewTopLevelObjects)) {
            print("BadgeView[loadNib]: Error Loading BadeView from NIB")
//            return
        }
        
        let indexOfCustomView = customViewTopLevelObjects!.indexOfObject( passingTest: { (object:Any, index:Int, stop:UnsafeMutablePointer<ObjCBool>) -> Bool in
            return (object as AnyObject).isKind(of: NSView.self)
        })
        
        customView = customViewTopLevelObjects![indexOfCustomView] as? NSView

        addSubview(customView)
    }
*/
    func loadNib() {
        var topLevelObjects: NSArray?
        let myBundle = Bundle(for: type(of: self))

        if myBundle.loadNibNamed(_nibName!, owner: self, topLevelObjects: &topLevelObjects) {
            customView = topLevelObjects?.first(where: { $0 is NSView }) as? NSView
            addSubview(customView)
        } else {
            print("Error trying to load the Xib: \(_nibName!)")
        }
    }
    
    //
    // MARK: - Drawing
    //
    
    public override var intrinsicContentSize:NSSize {
        // Base the intrinsic width of the badge of the width of the count string
        
        let stringToUseForLabelWidthCalculation = customCountStringToUseToCalculateIntrinsicContentSize ?? "\(count)"
        customCountStringToUseToCalculateIntrinsicContentSize = nil
        
        let labelWidth = label.font!.widthOfString(string: stringToUseForLabelWidthCalculation)
        
        let horizontalSizeOfBadgeWithPadding = labelWidth + horizontalPadding
        
        return NSMakeSize(horizontalSizeOfBadgeWithPadding, NSView.noIntrinsicMetric)
    }
    
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Fill the background with the background colour.
        backgroundColor!.set()
        self.bounds.fill()
        
        // Round those corners. If width == height, should be a perfect circle.
        self.layer?.cornerRadius = self.frame.height / 2
    }
    
    
    //
    // MARK: - Badge animation and update methods.
    //
    
    func showBadgeWithAnimation() {
        self.isHidden = false
        
        // Update the last count, before we forget ;)
        lastCount = count
        
        //
        // Animate the badge so it bounces up, scales down, and fades out:
        //
        //
        //          t=0    t=0.3       t=0.6        t=1.0
        //           |_________|_________|____________|
        // Opacity: 1.0                 1.0          0.0
        // Scale:   1.0       1.3                    0.0
        //
        // Easing function: ease-in-ease-out.
        //
        
        CATransaction.setCompletionBlock()
            {
                // Hide the badge on completion.
                self.isHidden = false
        }
        
        let animationDuration = 0.4
        
        //
        // Fade animation.
        //
        let fadeAnimation = CAKeyframeAnimation(keyPath: "opacity")
        
        fadeAnimation.keyTimes = [0.0, 0.3, 1.0]
        fadeAnimation.values = [0.0, 1.0, 1.0]
        
        fadeAnimation.duration = animationDuration
        fadeAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        
        //
        // Scale animation.
        //
        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform")
        
        scaleAnimation.keyTimes = [0.0, 0.6, 1.0]
        scaleAnimation.values =
            [
                NSValue(caTransform3D: CATransform3DMakeScale(0.1, 0.1, 0.1)),
                NSValue(caTransform3D: CATransform3DMakeScale(1.5, 1.5, 1.5)),
                NSValue(caTransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0))
        ]
        
        scaleAnimation.duration = animationDuration
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        
        // Set toe anchor point to the middle without making the layer jump.
        self.setAnchorPoint(anchorPoint: CGPoint(x: 0.5, y: 0.5))
        
        CATransaction.begin()
        self.layer!.add(scaleAnimation, forKey: "transform")
        self.layer!.add(fadeAnimation, forKey: "opacity")
        CATransaction.commit()
    }
    
    func hideBadgeWithAnimation() {
        //
        // Don’t change the last count displayed while animating the badge out.
        // (So, for example, if the last count was 42 and then count is set to zero,
        // people should see the 42 animating out.)
        //
        customCountStringToUseToCalculateIntrinsicContentSize = "\(lastCount)"
        lastCount = count
        
        //
        // Animate the badge so it bounces up, scales down, and fades out:
        //
        //
        //          t=0    t=0.3       t=0.6        t=1.0
        //           |_________|_________|____________|
        // Opacity: 1.0                 1.0          0.0
        // Scale:   1.0       1.3                    0.0
        //
        // Easing function: ease-in-ease-out.
        //
        
        CATransaction.setCompletionBlock()
            {
                // Hide the badge on completion.
                self.isHidden = true
        }
        
        let animationDuration = 0.4
        
        //
        // Fade animation.
        //
        let fadeAnimation = CAKeyframeAnimation(keyPath: "opacity")
        
        fadeAnimation.keyTimes = [0.0, 0.6, 1.0]
        fadeAnimation.values = [1.0, 1.0, 0.0]
        
        fadeAnimation.duration = animationDuration
        fadeAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        
        fadeAnimation.isRemovedOnCompletion = false
        fadeAnimation.fillMode = CAMediaTimingFillMode.forwards
        
        //
        // Scale animation.
        //
        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform")
        
        scaleAnimation.keyTimes = [0.0, 0.3, 1.0]
        scaleAnimation.values =
            [
                NSValue(caTransform3D: CATransform3DMakeScale(1.0, 1.0, 1.0)),
                NSValue(caTransform3D: CATransform3DMakeScale(1.3, 1.3, 1.3)),
                NSValue(caTransform3D: CATransform3DMakeScale(0.1, 0.1, 0.1))
        ]
        
        scaleAnimation.duration = animationDuration
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        
        // Make sure that the animation remains (isn’t automatically cleaned up), otherwise
        // there is a random flicker before the Core Animation transaction’s completion
        // block is called.
        scaleAnimation.isRemovedOnCompletion = false
        scaleAnimation.fillMode = CAMediaTimingFillMode.forwards
        
        // Set the anchor point to the middle without making the layer jump.
        self.setAnchorPoint(anchorPoint: CGPoint(x: 0.5, y: 0.5))
        
        CATransaction.begin()
        self.layer?.add(scaleAnimation, forKey: "transform")
        self.layer?.add(fadeAnimation, forKey: "opacity")
        CATransaction.commit()
    }
    
    func updateBadgeWithAnimation() {
        //
        // Animates the size of the badge based on the count.
        //
        
        // Update the last count.
        lastCount = count
        
        isHidden = false
        
        NSAnimationContext.runAnimationGroup(
            {
                /* with */ (context:NSAnimationContext!) -> Void in
                
                context.duration = 0.33
                context.allowsImplicitAnimation = true
                
                self.superview!.layoutSubtreeIfNeeded()
        },
            completionHandler:nil)
    }
    
    //
    // MARK: Interface builder design view.
    //
    
    public override func prepareForInterfaceBuilder() {
        loadNib()
    }
}
