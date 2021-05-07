package entities;

import flixel.FlxState;
import flixel.FlxObject;
import flixel.math.FlxPoint;
import flixel.util.FlxPath;
import flixel.util.FlxColor;
import js.html.Console;

class Entity
{
    private var SIGHT_ANGLE:Float = 0.0;
    private var SIGHT_RANGE:Float = 0;
    private var NEARBY_SIGHT_RADIUS:Float = 0.0;

    var sprite:SpriteWrapper<Entity>;
    var type:EntityType;

    // Hitboxes used by this entity.
    // Hitboxes are used by entities to do additional collision checks over other areas.
    var hitboxes:Array<Hitbox>;

    var seenEntities:Array<Entity>;

    var isJumpingCliff:Bool;
    var canJumpCliffs = true;

    public function new()
    {
        sprite = new SpriteWrapper<Entity>(this);
        hitboxes = new Array<Hitbox>();
        seenEntities = new Array<Entity>();
    }

    function setGraphic(width:Int, height:Int, dir:String, isAnimated:Bool)
    {
        sprite.loadGraphic(dir, isAnimated, width, height);
        sprite.setSize(width, height);
    }

    function setSprite(width:Int, height:Int, color:FlxColor)
    {
        sprite.makeGraphic(width, height, color);
        sprite.setSize(width, height);
    }

    public function update(elapsed:Float)
    {
        if (isJumpingCliff)
        {
            if (sprite.path.finished)
            {
                sprite.path = null;
                isJumpingCliff = false;
            }

            sprite.velocity.set(0,0);
        }

        // Update our sprite
        sprite.update(elapsed);

        for (hitbox in hitboxes)
        {
            hitbox.getSprite().x = getX();
            hitbox.getSprite().y = getY();
            hitbox.update(elapsed);
        }

        // Delete all seen entities.
        // These will be refilled in during the following collision check cycle.
        seenEntities.resize(0);
    }

    public function addHitbox(hitbox:Hitbox)
    {
        // Add to hitboxes array
        hitboxes.push(hitbox);

        // Add hitbox entity to world
        PlayState.world.addEntity(hitbox, false);
    }

    public function handleCollision(entity:Entity)
    {
        switch (entity.type)
        {
            case EntityPlayer:
                handlePlayerCollision(cast entity);
            case EntityPrey:
                handleDinoCollision(cast entity);
                handlePreyCollision(cast entity);
            case EntityCave:
                handleCaveCollision(cast entity);
            case EntityPredator:
                handleDinoCollision(cast entity);
                handlePredatorCollision(cast entity);
            case EntityBoulder:
                handleBoulderCollision(cast entity);
            default:
        }
    }

    public function notifyHitboxCollision(hitbox:Hitbox, entity:Entity) {}
    public function handlePlayerCollision(player:Player) {}
    public function handlePreyCollision(prey:Prey) {}
    public function handleCaveCollision(cave:Cave) {}
    public function handlePredatorCollision(predator:Predator) {}
    public function handleBoulderCollision(boulder:Boulder) {}
    public function handleDinoCollision(dino:Dino) {}

    /* Setters & Getters */
    public function setPosition(x:Float, y:Float)
    {
        sprite.setPosition(x, y);
    }

    public function getSprite()
    {
        return sprite;
    }

    public function getType()
    {
        return type;
    }

    public function handleCliffCollision(direction:Int)
    {
        if (!canJumpCliffs)
        {
            return;
        }

        var jumpDist = 25;
        
        var endx = sprite.x;
        var endy = sprite.y;
        var theta0 = 0.0;
        var theta1 = 0.0;
        var radiusX = jumpDist/2;
        var radiusY = jumpDist/2;
        switch (direction)
        {
            case FlxObject.UP:
                endy -= jumpDist;
                theta0 = Math.PI/2;
                theta1 = -Math.PI/2;
                radiusX /= 1.5;
            case FlxObject.DOWN:
                endy += jumpDist;
                theta0 = -Math.PI/2;
                theta1 = Math.PI/2;
                radiusX /= 1.5;
            case FlxObject.LEFT:
                endx -= jumpDist;
                theta0 = 2 * Math.PI;
                theta1 = Math.PI;
                radiusY /= 1.5;
            case FlxObject.RIGHT:
                endx += jumpDist;
                theta0 = Math.PI;
                theta1 = 2 * Math.PI;
                radiusY /= 1.5;
            default:
        }

        var startx = sprite.x;
        var starty = sprite.y;
        sprite.x = endx;
        sprite.y = endy;
        var colliding = GameWorld.collidingWithObstacles(this);
        sprite.x = startx;
        sprite.y = starty;

        if (colliding)
        {
            // Don't jump off cliff if we're jumping into an obstacle.
            return;
        }

        var centerX = (endx + sprite.x) / 2;
        var centerY = (endy + sprite.y) / 2;


        isJumpingCliff = true;
        sprite.path = new FlxPath();
        var pathLength = 10;
        for (i in 0...pathLength)
        {
            var theta = cast(i, Float) / cast(pathLength, Float) * (theta1 - theta0) + theta0;
            var pathX = centerX + Math.cos(theta) * radiusX;
            var pathY = centerY + Math.sin(theta) * radiusY;
            sprite.path.add(pathX, pathY);
        }
        sprite.path.add(endx, endy);
        sprite.path.start(null, 60.0);
    }

    public function getSightRange():Float
    {
        return this.SIGHT_RANGE;
    }

    public function getSightAngle():Float
    {
        return this.SIGHT_ANGLE;
    }

    public function getNearbySightRadius():Float
    {
        return this.NEARBY_SIGHT_RADIUS;
    }

    public function seen(entity: Entity)
    {
       seenEntities.push(entity);
    }

    public function getVelocityX():Float
    {
        return this.sprite.velocity.x;
    }

    public function getVelocityY():Float
    {
        return this.sprite.velocity.y;
    }

    public function getX()
    {
        return this.sprite.getMidpoint().x;
    }
    
    public function getY()
    {
        return this.sprite.getMidpoint().y;
    }
}
