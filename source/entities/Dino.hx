package entities;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import js.html.Console;

enum DinoState
{
    Herded;
    Unherded;
    Pursuing;
    Fleeing;
}

class Dino extends Entity
{
    var state:DinoState;
    
    // Constants
    final MAX_FOLLOWING_RADIUS = 150.0;
    final MAX_PLAYER_FOLLOWING_RADIUS = 30.0;
    final FOLLOWING_RADIUS = 15.0;
    final DAMPING_FACTOR = 0.8;
    final UNHERDED_SPEED = 30.0;

    final HERDED_HITBOX_ID = 0;

    /* State for herded behavior */
    var herdedPlayer:Player;
    var herdedLeader:Entity;
    var herdedSpeed:Float;

    // State for pathfinding
    var isPathfinding:Bool = false;

    var lastPosition:FlxPoint = new FlxPoint();
    var framesStuck:Int = 0;
    var herdedPath:Array<FlxPoint> = new Array<FlxPoint>();
    var framesSincePathGenerated:Int = 0;

    var collisionVector:FlxPoint = new FlxPoint();
    var collidedWithDino:Int = 0;

    public var herdedDisableFollowingRadius = false;

    /* State for unherded behavior */
    var idleTimer:Float;
    var moveDirection:Float;

    public function new()
    {
        super();

        setSprite(20, 20, FlxColor.YELLOW);
        sprite.mass = 1.0; // Make the dino easier to push by player.
        state = Unherded;
        
        var herdedHitbox = new Hitbox(this, HERDED_HITBOX_ID);
        herdedHitbox.getSprite().makeGraphic(16, 16, FlxColor.BLUE);
        addHitbox(herdedHitbox);

        idleTimer = 0;
    }

    public override function update(elapsed:Float)
    {
        switch (state)
        {
            case Unherded:
                unherded(elapsed);
            case Herded:
                herded(elapsed);
            case Fleeing:
                fleeing(elapsed);
            default:
        }

        // If we're herded but our leader is unherded, switch to unherded.
        if (state == Herded && Std.is(herdedLeader, Dino) && cast(herdedLeader, Dino).getState() == Unherded)
        {
            setUnherded();
        }

        // Update animation
        if ((sprite.velocity.x != 0 || sprite.velocity.y != 0) && sprite.touching == FlxObject.NONE)
        {
            if (Math.abs(sprite.velocity.x) > Math.abs(sprite.velocity.y))
            {
                if (sprite.velocity.x < 0)
                    sprite.facing = FlxObject.LEFT;
                else
                    sprite.facing = FlxObject.RIGHT;
            }
            else
            {
                if (sprite.velocity.y < 0)
                    sprite.facing = FlxObject.UP;
                else
                    sprite.facing = FlxObject.DOWN;
            }

            switch (sprite.facing)
            {
                case FlxObject.LEFT, FlxObject.RIGHT:
                    sprite.animation.play("lr");

                case FlxObject.UP:
                    sprite.animation.play("u");

                case FlxObject.DOWN:
                    sprite.animation.play("d");
            }
        }

        lastPosition = sprite.getPosition();
        collidedWithDino = 0;
        collisionVector.set(0,0);
        
        super.update(elapsed);
    }

    // Used by Player class to update herd ordering.
    public function setLeader(entity:Entity)
    {
        herdedLeader = entity;
    }

    // Called by Player when the herd has been scattered
    public function notifyScattered()
    {
        this.state = Unherded;
    }

    function unherded(elapsed:Float)
    {
        sprite.velocity.set(0, 0);
    }

    function herded(elapsed:Float)
    {
        herdedSpeed = herdedPlayer.getSpeed();
        var leaderPos = new FlxPoint(herdedLeader.getX(), herdedLeader.getY());
        var playerPos = new FlxPoint(herdedPlayer.getX(), herdedPlayer.getY());
        var dinoPos = new FlxPoint(getX(), getY());
        var distLeader = leaderPos.distanceTo(dinoPos);
        var distPlayer = playerPos.distanceTo(dinoPos);

        if (collidedWithDino > 4)
        {
            sprite.velocity.x += collisionVector.x / collidedWithDino * 0.1;
            sprite.velocity.y += collisionVector.y / collidedWithDino * 0.1;
        }

        var playerVelocity = herdedPlayer.getSprite().velocity;
        if (!herdedDisableFollowingRadius && GameWorld.magnitude(playerVelocity) < herdedSpeed / 10 && distPlayer < MAX_PLAYER_FOLLOWING_RADIUS * 2)
        {
            // If the player is not moving and we're nearby, stop moving as well.
            // This is to prevent congestion around the player.
            sprite.velocity.scale(DAMPING_FACTOR);
            return;
        }

        if (GameWorld.checkVision(this, herdedPlayer) && !herdedDisableFollowingRadius && distPlayer >= MAX_PLAYER_FOLLOWING_RADIUS && framesStuck == 0)
        {
            // If we can see the player, move directly towards them.
            moveTowards(playerPos, herdedSpeed);
            return;
        }

        if (!herdedDisableFollowingRadius && distLeader < FOLLOWING_RADIUS)
        {
            // Slow dino down
            sprite.velocity.scale(DAMPING_FACTOR);
            framesStuck = 0;
            return;
        }

        var positionDiff = new FlxPoint(lastPosition.x - dinoPos.x, lastPosition.y - dinoPos.y);
        if (!GameWorld.checkVision(this, herdedLeader) || GameWorld.magnitude(positionDiff) < herdedSpeed/10)
        {
            Console.log("Stuck.");
            framesStuck++;
        }
        else
        {
            framesStuck = 0;
        }

        // Check if the leader is pathfinding. If they are, also begin pathfinding to get around obstacle.
        var isLeaderPathfinding = false;
        if (Std.is(herdedLeader.getType(), Dino) && cast(herdedLeader, Dino).getIsPathfinding())
        {
            isLeaderPathfinding = true;
        }
        
        // Check if we should be pathfinding right now.
        // Begin pathfinding if leader is using pathfinding, or if we're stuck.
        if ((isLeaderPathfinding || framesStuck > 5) && (herdedPath.length == 0 || framesSincePathGenerated > 5))
        {
            // Attempt to pathfind towards herded leader
            Console.log("Finding new path.");
            var offset = 24;
            if (sprite.touching & FlxObject.LEFT > 0)
                dinoPos.x += offset;
            else if (sprite.touching & FlxObject.RIGHT > 0)
                dinoPos.x -= offset;
            else if (sprite.touching & FlxObject.UP > 0)
                dinoPos.y += offset;
            else if (sprite.touching & FlxObject.DOWN > 0)
                dinoPos.y -= offset;
            var newPath = PlayState.world.getObstacles().findPath(leaderPos, dinoPos);
            if (newPath != null)
            {
                herdedPath = newPath;
                framesSincePathGenerated = 0;
            } else Console.log("No path found.");
            framesStuck = 0;
        }

        if (herdedPath.length > 0)
        {
            // We are currently pathfinding.
            Console.log("Following path.");
            isPathfinding = true;
            // Follow the path towards the leader
            var pathPoint = herdedPath[herdedPath.length-1];
            var dir = new FlxPoint(pathPoint.x - dinoPos.x, pathPoint.y - dinoPos.y);
            if (GameWorld.magnitude(dir) < 1.0)
            {
                // We've reached this point; move to the next one.
                herdedPath.pop();

                // If the path is empty, return. There's nothing left to do.
                if (herdedPath.length == 0) return;
                pathPoint = herdedPath[herdedPath.length-1];
            }

            // Move towards the next point on the path.
            moveTowards(pathPoint, herdedSpeed);
            framesSincePathGenerated++;
        }
        else
        {
            // Moving based on line of sight; no pathfinding.
            isPathfinding = false;

            // Move directly towards leader
            moveTowards(leaderPos, herdedSpeed);
        }

        if (distLeader > MAX_FOLLOWING_RADIUS)
        {
            setUnherded(true);
        }
    }

    function moveTowards(position:FlxPoint, speed:Float)
    {
        var dir = new FlxPoint(position.x - getX(), position.y - getY());
        var angle = Math.atan2(dir.y, dir.x);
        sprite.velocity.set(Math.cos(angle) * speed, Math.sin(angle) * speed);
    }

    /* State transition methods */
    public function setUnherded(notify:Bool = false)
    {
        var player = herdedPlayer;
        herdedLeader = null;
        herdedPlayer = null;
        state = Unherded;

        herdedDisableFollowingRadius = false;

        player.notifyUnherded(this);
    }

    public function getState()
    {
        return state;
    }

    public function getHerdedPlayer()
    {
        return herdedPlayer;
    }

    public function getIsPathfinding()
    {
        return isPathfinding;
    }

    function handleCollidedWithDino(dino:Dino)
    {
        if (dino.getState() == Herded)
        {
            collidedWithDino++;
        }
    }

    function idle(elapsed:Float)
    {
        if (idleTimer <= 0)
        {
            if (FlxG.random.bool(25))
            {
                moveDirection = -1;
                sprite.velocity.x = sprite.velocity.y = 0;
            }
            else
            {
                moveDirection = FlxG.random.int(0, 8) * 45;

                sprite.velocity.set(UNHERDED_SPEED * 0.5, 0);
                sprite.velocity.rotate(FlxPoint.weak(), moveDirection);
            }
            idleTimer = FlxG.random.int(1, 4);
        }
        else
        {
            idleTimer -= elapsed;
        }
    }

    function fleeing(elapsed:Float)
    {
        if (seenEntities.length == 0)
        {
            state = Unherded;
        }
        else
        {
            var entity = GameWorld.getNearestEntity(this, seenEntities);
            var dir = new FlxPoint(this.sprite.x - entity.getSprite().x, this.sprite.y - entity.getSprite().y);
            var angle = Math.atan2(dir.y, dir.x);
            sprite.velocity.set(Math.cos(angle) * UNHERDED_SPEED, Math.sin(angle) * UNHERDED_SPEED);
        }
    }

    public override function notifyHitboxCollision(hitbox:Hitbox, entity:Entity)
    {
        if (hitbox.getId() == HERDED_HITBOX_ID)
        {
            if (entity.type == EntityPrey || entity.type == EntityPredator)
            {
                var diffX = this.getX() - entity.getX();
                var diffY = this.getY() - entity.getY();
                collisionVector.x += diffX;
                collisionVector.y += diffY;
                collidedWithDino++;
            }
        }
    }
}
