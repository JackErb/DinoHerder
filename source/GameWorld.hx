package;

import entities.*;
import flixel.math.FlxMath;
import flixel.FlxObject;
import flixel.math.FlxPoint;
import js.html.Console;

class GameWorld
{
    static var levelIndex = 0;
    static var levelArray = [AssetPaths.tutorial0__json, 
                            AssetPaths.tutorial1__json,
                            AssetPaths.tutorial2__json,
                            AssetPaths.tutorial3__json,
                            AssetPaths.Sandbox__json];

    static public function getNearestEntity(src:Entity, entities:Array<Entity>)
    {
        var nearestEntity = null;
        var minDistance = FlxMath.MAX_VALUE_FLOAT;

        for (entity in entities)
        {
            var distance = entityDistance(src, entity);
            if (distance < minDistance)
            {
                minDistance = distance;
                nearestEntity = entity;
            }
        }
        return nearestEntity;
    }

    static public function pointDistance(x1:Float, y1:Float, x2:Float, y2:Float)
    {
        return Math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
    }

    static public function entityDistance(src:Entity, dst:Entity)
    {
        var midpoint1 = src.getSprite().getMidpoint();
        var midpoint2 = dst.getSprite().getMidpoint();
        return pointDistance(midpoint1.x, midpoint1.y, midpoint2.x, midpoint2.y);
    }

    static public function entityAngle(src:Entity, dst:Entity)
    {
        var midpoint1 = src.getSprite().getMidpoint();
        var midpoint2 = dst.getSprite().getMidpoint();
        return pointAngle(1, 0, midpoint2.x - midpoint1.x, midpoint2.y - midpoint1.y);
    }

    static public function pointAngle(x1:Float, y1:Float, x2:Float, y2:Float)
    {
        var dot = x1 * x2 + y1 * y2;
        var cross = x1 * y2 - x2 * y1;
        return Math.atan2(cross, dot);
    }


    /* CLIFF COLLISIONS */ 
    static public function handleDownCliffCollision(tile:FlxObject, entity:FlxObject)
    {
        handleCliff(entity, FlxObject.UP);
    }

    static public function handleUpCliffCollision(tile:FlxObject, entity:FlxObject)
    {
        handleCliff(entity, FlxObject.DOWN);
    }

    static public function handleRightCliffCollision(tile:FlxObject, entity:FlxObject)
    {
        handleCliff(entity, FlxObject.LEFT);
    }

    static public function handleLeftCliffCollision(tile:FlxObject, entity:FlxObject)
    {
        handleCliff(entity, FlxObject.RIGHT);
    }

    static function handleCliff(entity:FlxObject, direction:Int)
    {
        if (Std.is(entity, SpriteWrapper))
        {
            var sprite:SpriteWrapper<Entity> = cast entity;
            var entity = sprite.entity;
            if (entity.getSprite().facing == direction)
            {
                entity.handleCliffCollision(direction);
            }
        }
    }



    /* VISION CHECKS */
    static public function checkVision(from:Entity, to:Entity):Bool
    {
        if (checkNearbySightRadius(from, to) || checkSightRange(from, to))
        {
            var obstacles = PlayState.world.getObstacles();
            if (obstacles.ray(from.getSprite().getMidpoint(), to.getSprite().getMidpoint(), null, 4))
            {
                return true;
            }
        }
        return false;
    }

    static function checkNearbySightRadius(from:Entity, to:Entity):Bool
    {
        return GameWorld.entityDistance(from, to) < from.getNearbySightRadius();
    }

    public static function checkSightRange(from:Entity, to:Entity):Bool
    {
        var range = GameWorld.entityDistance(from, to);

        var velocity = from.getSprite().velocity;
        // Angle between positive x axis and velocity vector
        var velocityAngle = GameWorld.pointAngle(1, 0, velocity.x, velocity.y);
        // Angle between the two entities
        var angleBetween = GameWorld.entityAngle(from, to);
        var angle = angleBetween - velocityAngle;

        return range < from.getSightRange() && Math.abs(angle) < from.getSightAngle() / 2;
    }



    static public function collidingWithObstacles(entity:Entity)
    {
        return PlayState.world.getObstacles().overlapsAt(0, 0, entity.getSprite());
    }

    static public function radians(degrees:Int)
    {
        return degrees * Math.PI / 180.0;
    }

    static public function magnitude(vector:FlxPoint)
    {
        return pointDistance(0, 0, vector.x, vector.y);
    }

    static public function random(min:Float, max:Float)
    {
        return Math.random() * (max - min) + min;
    }

    static public function toRadians(degrees:Int)
    {
        return degrees * Math.PI / 180.0;
    }

    static public function toDegrees(radians:Float)
    {
        return radians * 180.0 / Math.PI;
    }

    static public function getNextMap()
    {   
        if (levelIndex < levelArray.length - 1) 
        {
            return levelArray[levelIndex++];
        }
        else
        {
            return levelArray[levelIndex];
        }
    }
}
