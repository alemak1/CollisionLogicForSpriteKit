import SpriteKit

class Player : SKSpriteNode, GameSprite {
    var health: Int = 3
    var invulnerable = false
    var damaged = false
    var damageAnimation = SKAction()
    var dieAnimation = SKAction()
    var forwardVelocity: CGFloat = 200
    
    var initialSize = CGSize(width: 64, height: 64)
    var textureAtlas:SKTextureAtlas =
        SKTextureAtlas(named:"Pierre")
    // Pierre has multiple animations. Right now we will
    // create one animation for flying up, and one for going down:
    var flyAnimation = SKAction()
    var soarAnimation = SKAction()
    
    // Store whether we are flapping our wings or in free-fall:
    var flapping = false
    // Set a maximum upward force.
    // 57,000 feels good to me, adjust to taste:
    let maxFlappingForce:CGFloat = 57000
    // Pierre should slow down when he flies too high:
    let maxHeight:CGFloat = 1000
    
    init() {
        // Call the init function on the base class (SKSpriteNode)
        super.init(texture: nil, color: .clear, size: initialSize)
        
        createAnimations()
        // If we run an action with a key, "flapAnimation",
        // we can later reference that key to remove the action.
        self.run(soarAnimation, withKey: "soarAnimation")
        
        // Create a physics body based on one frame of Pierre's animation.
        // We will use the third frame, when his wings are tucked in
        let bodyTexture = textureAtlas.textureNamed("pierre-flying-3")
        self.physicsBody = SKPhysicsBody(
            texture: bodyTexture,
            size: self.size)
        // Pierre will lose momentum quickly with a high linearDamping:
        self.physicsBody?.linearDamping = 0.9
        // Adult penguins weigh around 30kg:
        self.physicsBody?.mass = 30
        // Prevent Pierre from rotating:
        self.physicsBody?.allowsRotation = false
        
        self.physicsBody?.categoryBitMask = PhysicsCategory.penguin.rawValue
        self.physicsBody?.contactTestBitMask = PhysicsCategory.enemy.rawValue | PhysicsCategory.ground.rawValue | PhysicsCategory.powerup.rawValue | PhysicsCategory.coin.rawValue
        
    }
    
    func createAnimations() {
        let rotateUpAction = SKAction.rotate(toAngle: 0, duration:
            0.475)
        rotateUpAction.timingMode = .easeOut
        let rotateDownAction = SKAction.rotate(toAngle: -1,
                                               duration: 0.8)
        rotateDownAction.timingMode = .easeIn
        
        // Create the flying animation:
        let flyFrames:[SKTexture] = [
            textureAtlas.textureNamed("pierre-flying-1"),
            textureAtlas.textureNamed("pierre-flying-2"),
            textureAtlas.textureNamed("pierre-flying-3"),
            textureAtlas.textureNamed("pierre-flying-4"),
            textureAtlas.textureNamed("pierre-flying-3"),
            textureAtlas.textureNamed("pierre-flying-2")
        ]
        let flyAction = SKAction.animate(with: flyFrames,
                                         timePerFrame: 0.03)
        // Group together the flying animation with rotation:
        flyAnimation = SKAction.group([
            SKAction.repeatForever(flyAction),
            rotateUpAction
            ])
        
        // Create the soaring animation, just one frame for now:
        let soarFrames:[SKTexture] =
            [textureAtlas.textureNamed("pierre-flying-1")]
        let soarAction = SKAction.animate(with: soarFrames,
                                          timePerFrame: 1)
        // Group the soaring animation with the rotation down:
        soarAnimation = SKAction.group([
            SKAction.repeatForever(soarAction),
            rotateDownAction
            ])
        
        let damageStart = SKAction.run({
            self.physicsBody?.categoryBitMask = PhysicsCategory.damagedPenguin.rawValue
            self.physicsBody?.collisionBitMask = ~PhysicsCategory.enemy.rawValue
        })
        
        let slowFade = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.7, duration: 0.35),
            SKAction.fadeAlpha(to: 0.3, duration: 0.35)
            ])
        
        
        let fastFade = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.7, duration: 0.2),
            SKAction.fadeAlpha(to: 0.3, duration: 0.2)
            ])
        
        let fadeInAndOut = SKAction.sequence([
            SKAction.repeat(slowFade, count: 5),
            SKAction.repeat(fastFade, count: 2),
            SKAction.fadeAlpha(to: 1, duration: 0.15)
            ])
        
        let damageEnd = SKAction.run({
            self.physicsBody?.categoryBitMask = PhysicsCategory.penguin.rawValue
            self.physicsBody?.collisionBitMask = 0xFFFFFFFF
            self.damaged = false
        })
        
        self.damageAnimation = SKAction.sequence([
            damageStart,
            fadeInAndOut,
            damageEnd
            ])
        
        let startDie = SKAction.run({
            self.texture = self.textureAtlas.textureNamed("pierre-dead.png")
            self.physicsBody?.affectedByGravity = false
            self.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
            self.physicsBody?.collisionBitMask = PhysicsCategory.ground.rawValue
        })
        
        let endDie = SKAction.run({
            self.physicsBody?.affectedByGravity = true
        })
        
        self.dieAnimation = SKAction.sequence([
                startDie,
                SKAction.scale(to: 1.3, duration: 0.5),
                SKAction.wait(forDuration: 0.5),
                SKAction.rotate(toAngle: 3, duration: 1.5),
                SKAction.wait(forDuration: 0.5),
                endDie
            ])
    }
    
    func update() {
        // If flapping, apply a new force to push Pierre higher.
        if self.flapping {
            var forceToApply = maxFlappingForce
            
            // Apply less force if Pierre is above position 600
            if position.y > 600 {
                // The higher Pierre goes, the more force we
                // remove. These next three lines determine the
                // force to subtract:
                let percentageOfMaxHeight = position.y / maxHeight
                let flappingForceSubtraction =
                    percentageOfMaxHeight * maxFlappingForce
                forceToApply -= flappingForceSubtraction
            }
            // Apply the final force:
            self.physicsBody?.applyForce(CGVector(dx: 0, dy:
                forceToApply))
        }
        
        // Limit Pierre's top speed as he climbs the y-axis.
        // This prevents him from gaining enough momentum to shoot
        // over our max height. We bend the physics for gameplay:
        if self.physicsBody!.velocity.dy > 300 {
            self.physicsBody!.velocity.dy = 300
        }
        
        // Set a constant velocity to the right:
        self.physicsBody?.velocity.dx = self.forwardVelocity
    }
    
    // Begin the flap animation, set flapping to true:
    func startFlapping() {
        if(self.health <= 0){ return }
        
        self.removeAction(forKey: "soarAnimation")
        self.run(flyAnimation, withKey: "flapAnimation")
        self.flapping = true
    }
    
    // Stop the flap animation, set flapping to false:
    func stopFlapping() {
        if(self.health <= 0){return}
        self.removeAction(forKey: "flapAnimation")
        self.run(soarAnimation, withKey: "soarAnimation")
        self.flapping = false
    }
    
    func die(){
        self.alpha = 1
        self.removeAllActions()
        self.run(dieAnimation)
        self.flapping = false
        self.forwardVelocity = 0
        
    
    }
    
    func takeDamage(){
        if(self.damaged || self.invulnerable) { return }
        
        self.damaged = true
        
        self.health -= 1
        
        if(self.health == 0){
            die()
        } else {
            self.run(self.damageAnimation)
        }
    
    }
    
    func onTap() {}
    
    // Satisfy the NSCoder required init:
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
