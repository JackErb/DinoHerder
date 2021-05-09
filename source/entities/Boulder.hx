package entities;

import flixel.FlxObject;
import js.html.Console;
import flixel.util.FlxPath;

class Boulder extends Entity
{
    final PUSH_SPEED = 0.4;

    var isInWater:Bool = false;

    public function new()
    {
        super();

        setGraphic(16, 16, AssetPaths.boulder__png, false);

        this.sprite.immovable = true;
        this.type = EntityBoulder;
        this.sprite.mass = 1000;
    }

    public function isCollidable():Bool
    {
        return !isInWater;
    }

    public function push(direction:Int)
    {
        if (isInWater) return;

        var prevX = this.sprite.x;
        var prevY = this.sprite.y;
        switch (direction)
        {
            case FlxObject.UP:
                this.sprite.y -= PUSH_SPEED;
            case FlxObject.DOWN:
                this.sprite.y += PUSH_SPEED;
            case FlxObject.RIGHT:
                this.sprite.x += PUSH_SPEED;
            case FlxObject.LEFT:
                this.sprite.x -= PUSH_SPEED;
            default:
        }

        if (GameWorld.collidingWithObstacles(this))
        {
            this.sprite.x = prevX;
            this.sprite.y = prevY;
        }
    }

    public function goIntoWater(x: Float, y: Float)
    {
        if (!isInWater)
        {
            // TODO animate path
            sprite.path = new FlxPath();
            sprite.path.add(sprite.x, sprite.y);
            sprite.path.add(x, y);
            sprite.path.onComplete = inWater;
            sprite.path.start(null, 70.0);

            isInWater = true;

            PlayState.world.removeFromCollidableSprites(this);
        }
    }

    public override function update(elapsed:Float)
    {
        if (isInWater && sprite.path != null && sprite.path.finished)
        {
            sprite.path = null;
            //inWater();
        }

        super.update(elapsed);
    }

    public function inWater(path:FlxPath)
    {
        PlayState.world.removeFromCollidableSprites(this);

        // Set adjacent tile to no collisions, if it's a ridge in the correct orientation
    }
}
