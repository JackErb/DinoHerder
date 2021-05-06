package entities;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import js.html.Console;

class Player extends Entity
{
    /* Hitbox id constants */
    static var INTERACT_HITBOX_ID = 0;

    var speed:Float = 40.0;

    // Array of followers. TODO: Should be linked list.
    var followers:Array<Dino>;
    var primaryFollower:Dino;

    // State variables
    var depositingToCave:Bool = false;
    var cave:Cave;
    var inRangeOfCave:Bool = false;

    public function new()
    {
        super();

        this.type = EntityPlayer;

        setGraphic(16, 16, AssetPaths.player__png, true);

        sprite.setFacingFlip(FlxObject.LEFT, false, false);
        sprite.setFacingFlip(FlxObject.RIGHT, true, false);

        sprite.animation.add("lr", [19, 20, 21, 22], 4, false);
        sprite.animation.add("u", [7, 8, 9, 10], 4, false);
        sprite.animation.add("d", [1, 2, 3, 4], 4, false);

        // sprite.screenCenter();

        sprite.setSize(6, 6);
        sprite.offset.set(4, 6);

        var interactHitbox = new Hitbox(this, INTERACT_HITBOX_ID);
        interactHitbox.getSprite().makeGraphic(24, 24, FlxColor.BLUE);
        addHitbox(interactHitbox);

        followers = new Array<Dino>();
    }

    public override function update(elapsed:Float)
    {
        move();

        // Cave depositing logic
        reorganizeHerd();

        if (!inRangeOfCave && depositingToCave)
        {
            // We are no longer in range of cave. Set herd back to normal order.
            depositingToCave = false;
            reorganizeHerd();
            for (dino in followers)
            {
                dino.herdedDisableFollowingRadius = false;
            }
        }

        if (depositingToCave && followers.length > 0)
        {
            primaryFollower.setLeader(cave);
            primaryFollower.herdedDisableFollowingRadius = true;
        }


        // Assume that we are now out of range of the cave.
        // If we're still in range, we'll be notified within the following collision checking cycle.
        inRangeOfCave = false;

        super.update(elapsed);
    }

    function reorganizeHerd()
    {
        var followersCopy = new Array<Dino>();
        for (dino in followers)
        {
            // Prune any Unherded dinosaurs
            if (dino.getState() == Herded)
            {
                followersCopy.push(dino);
            }
        }

        var lastEntity:Entity = this;
        var first = true;

        while (followersCopy.length > 0)
        {
            var dino:Dino = cast GameWorld.getNearestEntity(lastEntity, cast followersCopy);
            // TODO: This is inefficient
            followersCopy.remove(dino);

            if (first)
            {
                primaryFollower = dino;
                first = false;
            }

            dino.setLeader(lastEntity);
            lastEntity = dino;
        }
    }

    function move()
    {
        var up = FlxG.keys.anyPressed([UP, W]);
        var down = FlxG.keys.anyPressed([DOWN, S]);
        var left = FlxG.keys.anyPressed([LEFT, A]);
        var right = FlxG.keys.anyPressed([RIGHT, D]);

        if (up && down)
            up = down = false;

        if (left && right)
            left = right = false;

        var angle = 0.0;
        if (up)
        {
            angle = 270;
            if (left)
                angle -= 45;
            if (right)
                angle += 45;
            sprite.facing = FlxObject.UP;
        }
        else if (down)
        {
            angle = 90;
            if (left)
                angle += 45;
            if (right)
                angle -= 45;
            sprite.facing = FlxObject.DOWN;
        }
        else if (left)
        {
            angle = 180;
            sprite.facing = FlxObject.LEFT;
        }
        else if (right)
        {
            angle = 0;
            sprite.facing = FlxObject.RIGHT;
        }
        else
        {
            // Player is not moving
            sprite.velocity.set(0, 0);
            return;
        }

        angle *= Math.PI / 180;
        sprite.velocity.set(Math.cos(angle) * speed, Math.sin(angle) * speed);

        if ((sprite.velocity.x != 0 || sprite.velocity.y != 0) && sprite.touching == FlxObject.NONE)
        {
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
    }

    public function notifyUnherded(dino:Dino)
    {
        /*var unherdedIndex = -1;
        for (i in 0...followers.length)
        {
            if (unherdedIndex == -1 && followers[i].getState() == Unherded)
            {
                unherdedIndex = i;
            }

            if (unherdedIndex != -1 && i > unherdedIndex)
            {
                followers[i].setUnherded();
            }
        }

        if (unherdedIndex != -1)
        {
            followers.resize(unherdedIndex);
        }*/
        followers.remove(dino);
    }

    public function notifyCaveDeposit(dino:Dino)
    {
        if (depositingToCave)
        { 
            // Remove entity from world
            followers.remove(dino);
            PlayState.world.removeEntity(dino);
            PlayState.world.incrementScore(1);
            depositingToCave = false;
        }
    }

    public function notifyDeadFollower(dino:Dino)
    {
        // TODO: Reimplement this w/ the sets
        /*
        var dinoIndex = followers.indexOf(dino);
        for (i in dinoIndex...followers.length)
        {
            followers[i].notifyScattered();
        }*/

        followers.remove(dino);
    }

    public function addDino(dino:Dino)
    {
        // Insert new dino to herd
        followers.push(dino);
    }

    public override function notifyHitboxCollision(hitbox:Hitbox, entity:Entity)
    {
        if (hitbox.getId() == INTERACT_HITBOX_ID)
        {
            if (entity.type == EntityCave)
            {
                inRangeOfCave = true;
            }
        }
    }

    public function isInRangeOfCave()
    {
        return this.inRangeOfCave;
    }

    public override function handleCaveCollision(cave:Cave)
    {
        depositingToCave = true;
        inRangeOfCave = true;
        this.cave = cave;
    }

    public override function handlePredatorCollision(predator:Predator)
    {
        if (predator.canEat(this))
        {
            // Unherd all dinosaurs.
            for (follower in followers)
            {
                follower.setUnherded();
            }
            followers.resize(0);

            // Move player to nearest cave.
            var caves = PlayState.world.getCaves();
            var nearestCave = GameWorld.getNearestEntity(this, cast caves);
            this.setPosition(nearestCave.sprite.x, nearestCave.sprite.y);
        }
    }

    // Return the Player's speed.
    public function getSpeed()
    {
        return this.speed;
    }

    // Return the Player's x coordinate.
    public function getX()
    {
        return this.sprite.x;
    }
    
    // Return the Player's y coordinate.
    public function getY()
    {
        return this.sprite.y;
    }
}
