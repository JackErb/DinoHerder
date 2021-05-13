import entities.*;
import entities.EntityType;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.editors.ogmo.FlxOgmo3Loader;
import flixel.group.FlxGroup;
import flixel.tile.FlxTilemap;
import flixel.util.FlxColor;
import js.html.Console;
import flixel.text.FlxText;
import flixel.FlxG;
import flixel.FlxBasic;
import flixel.tile.FlxTile;
import flixel.graphics.FlxGraphic;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;

class PlayState extends FlxState
{
    // A singleton reference to the global PlayState.
    public static var world:PlayState;

    static public final SCREEN_WIDTH = 800;
    static public final SCREEN_HEIGHT = 600;

    // Size of tiles/chunks
    static public final TILE_SIZE = 16;
    static public final CHUNK_WIDTH = 320;
    static public final CHUNK_HEIGHT = 240;

    static public final DEBUG = true;

    // Size of map (in # of tiles)
    var mapWidth = 0;
    var mapHeight = 0;

    // In world entities
    var player:Player;

    // Full array of in world of entities
    var entities:Array<Entity>;

    // FlxSprite groups.
    // Maps GroupdIds (defined above) to a group containing all of that type of entity
    var entityGroups:Map<EntityType, Array<Entity>>;
    var spriteGroups:Map<EntityType, FlxGroup>;
    
    var uncollidableTiles:Array<Int> = new Array<Int>();

    // A group containing all collidable entities
    var collidableSprites:FlxGroup;
    var staticCollidableSprites:FlxGroup;

    // The object that holds the ogmo map.
    var map:FlxOgmo3Loader;

    // The tilemaps generated from the ogmo map.
    var ground:FlxTilemap;
    var obstacles:FlxTilemap;

    var caves:Array<Cave>;
    var respawnCave:Cave;

    // The level's score;
    var scoreText:FlxText;

    // Screen transition
    var transitioningToNextLevel:Bool = false;
    var onEndScreen:Bool = false;
    var transitionScreen:FlxSprite;

    // This level's new, previously unseen entity.
    var newEntity:EntityType;
    var hasSeenNewEntity = false;
    var playerReaction:String;
    var entityReaction:String;

    // Used for score display
    public var numPlayerDeaths:Int = 0;
    public var numPreyDeaths:Int = 0;
    public var numPreyCollected:Int = 0;
    public var numPrey:Int = 0;

    override public function create()
    {
        super.create();

        // Set singleton reference
        PlayState.world = this;

        // Hide the cursor
        FlxG.mouse.visible = false;

        // Initialize member variables
        entityGroups = new Map<EntityType, Array<Entity>>();
        spriteGroups = new Map<EntityType, FlxGroup>();
        entities = new Array<Entity>();
        collidableSprites = new FlxGroup();
        staticCollidableSprites = new FlxGroup();
        caves = new Array<Cave>();

        for (type in Type.allEnums(EntityType))
        {
            entityGroups[type] = new Array<Entity>();
            spriteGroups[type] = new FlxGroup();
        }

        // Must have call to getNewEntity before call to getNextMap
        newEntity = GameWorld.getNewEntity();
        playerReaction = GameWorld.getPlayerReaction(newEntity);
        entityReaction = GameWorld.getEntityReaction(newEntity);
        // Add any tutorial information.
        for (tutorial in GameWorld.getTutorialInformation())
        {
            var tutorialText = new FlxText(tutorial.x, tutorial.y, tutorial.text);
            tutorialText.x -= tutorialText.width / 2;
            tutorialText.health = -9;
            tutorialText.alignment = CENTER;
            //tutorialText.borderStyle = SHADOW;
            add(tutorialText);
        }

        // Set up the tilemap.
        map = new FlxOgmo3Loader(AssetPaths.DinoHerder__ogmo, GameWorld.getNextMap());

        // Static Entities.
        // Load tiles from tile maps
        ground = map.loadTilemap(AssetPaths.Tileset__png, "ground");
        ground.useScaleHack = true;
        ground.follow();
        add(ground);

        obstacles = map.loadTilemap(AssetPaths.Tileset__png, "obstacles");
        obstacles.useScaleHack = true;

        mapWidth = obstacles.widthInTiles;
        mapHeight = obstacles.heightInTiles;
        
        obstacles.follow();
        obstacles.health = bottomLayerSortIndex();
        add(obstacles);

        // Make all obstacles collidable.
        for (x in 0...obstacles.widthInTiles)
        {
            for (y in 0...obstacles.heightInTiles)
            {
                createTileCollider(x, y, obstacles);
            }
        }

        // Load entities from tilemap
        map.loadEntities(placeEntities, "entities");

        // Set cliff collision handlers
        CollisionHandler.setTileCollisions(obstacles);
        
        // Set the initial respawn cave to be the cave nearest the player at level start.
        respawnCave = cast GameWorld.getNearestEntity(player, entityGroups[EntityCave]);

        // Set up camera
        setupCamera();

        // Set up score counter
        scoreText = new FlxText(0, 0, 0, "", 10);
        scoreText.alpha = 0;
        scoreText.setBorderStyle(SHADOW, FlxColor.BLACK, 1, 1);
        scoreText.health = topLayerSortIndex();
        add(scoreText);

        // Set up transition screen
        transitionScreen = new FlxSprite(-10, -10);
        transitionScreen.makeGraphic(TILE_SIZE * mapWidth + 10, TILE_SIZE * mapHeight + 10, FlxColor.BLACK);
        transitionScreen.alpha = 1;
        transitionScreen.health = topLayerSortIndex() + 1;
        add(transitionScreen);

        PlayLogger.startLevel(GameWorld.levelId());
    }

    function setupCamera()
    {
        // Set world size
        FlxG.worldBounds.set(0, 0, TILE_SIZE * mapWidth, TILE_SIZE * mapHeight);

        // Set camera to follow player
        FlxG.camera.setScrollBoundsRect(0, 0, TILE_SIZE * mapWidth, TILE_SIZE * mapHeight);
        FlxG.camera.zoom = SCREEN_WIDTH / CHUNK_WIDTH;
        FlxG.camera.follow(player.getSprite(), TOPDOWN, 1);

        var camera_x = SCREEN_WIDTH/2;
        var camera_y = SCREEN_HEIGHT/2;
        var camera_w = CHUNK_WIDTH/4;
        var camera_h = CHUNK_HEIGHT/4;
        FlxG.camera.deadzone.set(camera_x - camera_w/2, camera_y - camera_h/2, camera_w, camera_h);
    }

    function createTileCollider(tileX:Int, tileY:Int, obstacles:FlxTilemap)
    {
        var tileNum = obstacles.getTile(tileX, tileY);
        if (tileNum == 0) return;

        var width = TileType.getWidthOfTile(tileNum);
        var height = TileType.getHeightOfTile(tileNum);
        if (width == 16 && height == 16)
        {
            // This tile doesn't need a custom hitbox. Keep it in the tilemap.
        }
        else
        {
            if (!uncollidableTiles.contains(tileNum)) uncollidableTiles.push(tileNum);

            var x = tileX * TILE_SIZE + TILE_SIZE/2 - width/2;
            var y = tileY * TILE_SIZE + TILE_SIZE/2 - height/2;

            var collider = new StaticObject(x, y, width, height, tileNum);
            collider.immovable = true;
            collider.visible = false;

            var sprite = new FlxSprite();
            sprite.loadGraphic(FlxGraphic.fromFrame(obstacles.frames.frames[tileNum]), false, 16, 16);
            sprite.setSize(16, 16);
            sprite.x = tileX * TILE_SIZE;
            sprite.y = tileY * TILE_SIZE;
            add(sprite);

            staticCollidableSprites.add(collider);
            add(collider);
        }
    }

    function nextLevel()
    {
        onEndScreen = true;
        
        var debugSkip = DEBUG && FlxG.keys.anyPressed([N]);
        if (this.numPrey == 0 || debugSkip)
        {
            // There are no prey on this level, so skip displaying the score.
            FlxG.switchState(new PlayState());
            return;
        }

        this.clear();

        // DIsplay the score for this level.
        var scoreString = "Saved: " + numPreyCollected + " / " + numPrey;
        
        var levelScoreText = new FlxText(0, 0, 0, scoreString, 18);
        levelScoreText.health = transitionScreen.health + 1;
        levelScoreText.alpha = 0;
        this.add(transitionScreen);
        this.add(levelScoreText);

        var camera = FlxG.camera;
        var x = camera.scroll.x + camera.width/2 - levelScoreText.width/2;
        var y = camera.scroll.y + camera.height/2 - levelScoreText.height/2;
        levelScoreText.setPosition(x, y);
        
        var setAlpha = function (f:Float) {
            levelScoreText.alpha = f;
        };

        Console.log(getFirstNull());
        Console.log(scoreString);

        var fadeOptions = {ease: FlxEase.quadInOut, onComplete: function (tween:FlxTween) {
            var fadeOutOptions = {ease:FlxEase.quadInOut, onComplete: function (tween:FlxTween) {
                PlayLogger.endLevel();
                FlxG.switchState(new PlayState());
            }};
            FlxTween.num(1.0, 0, 1.0, fadeOutOptions, setAlpha);
        }};
        FlxTween.num(0, 1.0, 1.0, fadeOptions, setAlpha);
    }

    function updateTransitionScreen()
    {
        if (onEndScreen) return;

        // Check to load next level.
        transitioningToNextLevel = player.isInRangeOfCave() && levelIsComplete();
        if (DEBUG)
        {
            if (FlxG.keys.anyPressed([N]))
            {
                nextLevel();
            }
        }

        // Update transition screen
        if (transitioningToNextLevel)
        {
            transitionScreen.alpha += 0.03;
            if (transitionScreen.alpha >= 1.0)
            {
                // Go to next level!
                nextLevel();
            }
        }
        else if (transitionScreen.alpha > 0)
        {
            transitionScreen.alpha -= 0.03;
        }
    }

    function updateScore()
    {
        scoreText.text = "" + Score.get();
        scoreText.x = player.getX() - scoreText.textField.textWidth/2;
        scoreText.y = player.getY() - scoreText.textField.textHeight/2 - 16;

        // Fade out score text.
        if (scoreText.alpha > 0)
        {
            scoreText.alpha -= 0.01;
        }
    }

    override public function update(elapsed:Float)
    {
        if (!PlayLogger.loggerInitialized())
        {
            // Don't execute update method until logger session has been created.
            return;
        }

        if (onEndScreen)
        {
            // Don't run any additional updates because we are currently on the ending screen.
            return;
        }

        PlayLogger.incrementTime(elapsed);
 
        // Do collision checks
        collisionChecks();
 
        updateTransitionScreen();
        updateScore();

        // Update all entities
        for (entity in entities)
        {
            entity.update(elapsed);
        }

        if (DEBUG)
        {
            if (FlxG.keys.anyPressed([P]))
            {
                var prey = new Prey();
                prey.setPosition(player.getSprite().x, player.getSprite().y);
                addEntity(prey);
            }
        }

        this.sort(sortSprites);
        super.update(elapsed);
    }
    
    public function topLayerSortIndex()
    {
        return mapHeight * TILE_SIZE * 2;
    }

    public function bottomLayerSortIndex()
    {
        return -mapHeight * TILE_SIZE;
    }


    function sortSprites(order:Int, obj1:FlxBasic, obj2:FlxBasic):Int {
        if (obj1 == null && obj2 == null)
        {
            return 0;
        }
        else if (obj1 == null)
        {
            return -1;
        }
        else if (obj2 == null)
        {
            return 1;
        }

        var check1 = Std.is(obj1, FlxTilemap);
        var check2 = Std.is(obj2, FlxTilemap);
        if (check1 && check2)
            return 0;
        else if (check1)
            return -1;
        else if (check2)
            return 1;
        else
        {
            var sprite1:FlxObject = cast obj1;
            var sprite2:FlxObject = cast obj2;

            var y1 = sprite1.y + sprite1.height/2;
            if (sprite1.health != 1)
                y1 = sprite1.health;

            var y2 = sprite2.y + sprite2.height/2;
            if (sprite2.health != 1)
                y2 = sprite2.health;

            return cast(y1 - y2);
        }
    }

    // Adds entity to the world and respective sprite group.
    public function addEntity(entity:Entity, collidable:Bool = true)
    {
        var type = entity.getType();
        var sprite = entity.getSprite();

        // Add to entities array
        entityGroups[type].push(entity);
        entities.push(entity);

        // Add sprite to FlxGroup (used for collision detection)
        spriteGroups[type].add(sprite);
        add(sprite);

        // Add to collidable entities
        if (collidable)
        {
            collidableSprites.add(sprite);
        }
    }

    public function removeEntity(entity:Entity)
    {
        var type = entity.getType();

        // Remove from entity arrays
        entityGroups[type].remove(entity);
        entities.remove(entity);

        // Remove from FlxGroups
        var sprite = entity.getSprite();
        spriteGroups[type].remove(sprite, true);
        collidableSprites.remove(sprite, true);
        remove(sprite, true);

        if (entity.getThought() != null)
        {
            remove(entity.getThought().sprite);
        }
    }

    public function removeFromCollidableSprites(entity:Entity)
    {
        collidableSprites.remove(entity.getSprite());
    }

    function collisionChecks()
    {
        var playerGroup = spriteGroups[EntityPlayer];
        var preyGroup = spriteGroups[EntityPrey];
        var predatorGroup = spriteGroups[EntityPredator];
        var caveGroup = spriteGroups[EntityCave];
        var hitboxGroup = spriteGroups[EntityHitbox];
        var boulderGroup = spriteGroups[EntityBoulder];

        // Collision resolution

        // Check collidable entity overlap
        FlxG.overlap(playerGroup, collidableSprites, handleCollision);
        FlxG.overlap(preyGroup, collidableSprites, handleCollision);
        FlxG.overlap(hitboxGroup, collidableSprites, handleCollision);

        // Check cave overlap
        FlxG.overlap(playerGroup, caveGroup, handleCollision);
        FlxG.overlap(preyGroup, caveGroup, handleCollision);
        FlxG.overlap(hitboxGroup, caveGroup, handleCollision);

        // Collision resolution -- physics
        FlxG.overlap(collidableSprites, collidableSprites, handleSeparationCollision);
        FlxG.collide(collidableSprites, staticCollidableSprites);
        
        // Collide with tilemap.
        // First, disable collisions for tiles that shouldn't be collided with.
        toggleAdditionalTilemapCollisions(false);
        // Do collision check.
        FlxG.collide(collidableSprites, obstacles);
        // Reenable the collisions.
        toggleAdditionalTilemapCollisions(true);

        // Vision checks
        for (predator in entityGroups[EntityPredator])
        {
            if (GameWorld.checkVision(predator, player))
            {
                predator.seen(player);
            }

            for (prey in entityGroups[EntityPrey])
            {
                if (GameWorld.checkVision(predator, prey))
                {
                    predator.seen(prey);
                }
                if (GameWorld.checkVision(prey, predator))
                {
                    prey.seen(predator);
                }
            }
        }


        if (newEntity != EntityNull)
        {
            for (entity in entityGroups[newEntity])
            {
                if (!hasSeenNewEntity && GameWorld.checkVision(player, entity)) // and in range
                {
                    player.think(playerReaction);
                    entity.think(entityReaction);
                    hasSeenNewEntity = true;
                }
            }
        }
    }

    public function toggleAdditionalTilemapCollisions(toggle:Bool)
    {
        // Reenable collisions (these collisions are used when raycasting).
        var collisions = toggle ? FlxObject.ANY : FlxObject.NONE;
        for (tileNum in uncollidableTiles)
        {
            obstacles.setTileProperties(tileNum, collisions);
        }
    }

    function placeEntities(entity:EntityData)
    {
        var x = entity.x;
        var y = entity.y;

        switch (entity.name)
        {
            case "player":
                player = new Player();
                player.setPosition(x, y, true);
                addEntity(player);
            case "prey":
                numPrey++;
                var prey = new Prey();
                prey.setPosition(x, y);
                addEntity(prey);
            case "predator":
                var predator = new Predator();
                predator.setPosition(x, y);
                addEntity(predator);
            case "cave":
                var cave = new Cave();
                cave.setPosition(x, y);
                addEntity(cave, false);
                caves.push(cave);
            case "boulder":
                var boulder = new Boulder();
                boulder.setPosition(x, y);
                addEntity(boulder);
        }
    }

    function handleCollision(s1:SpriteWrapper<Entity>, s2:SpriteWrapper<Entity>)
    {
        var e1 = s1.entity;
        var e2 = s2.entity;

        e1.handleCollision(e2);
        e2.handleCollision(e1);
    }

    function handleSeparationCollision(s1:SpriteWrapper<Entity>, s2:SpriteWrapper<Entity>)
    {
        var e1 = s1.entity;
        var e2 = s2.entity;

        var player:Player = null;
        if (e1.getType() == EntityPlayer) player = cast e1;
        if (e2.getType() == EntityPlayer) player = cast e2;

        var prey:Prey = null;
        if (e1.getType() == EntityPrey) prey = cast e1;
        if (e2.getType() == EntityPrey) prey = cast e2;

        var pred:Predator = null;
        if (e1.getType() == EntityPredator) pred = cast e1;
        if (e2.getType() == EntityPredator) pred = cast e2;

        if (player != null && prey != null && prey.getHerdedPlayer() == player)
        {
            return;
        }
        else if (pred != null && pred.isDazed())
        {
            return;
        }
        else
        {
            // Only separate them if the other conditions are not met.
            FlxObject.separate(s1, s2);
        }
    }

    public function getCaves()
    {
        return caves;
    }

    function levelIsComplete()
    {
        return entityGroups[EntityPrey].length == 0;
    }

    public function incrementScore(amount:Int):Void
    {
        Score.increment(amount);
        scoreText.alpha = 1;
    }

    public function getObstacles()
    {
        return obstacles;
    }

    public function getStaticObstacles()
    {
        return staticCollidableSprites;
    }

    public function triggerLevelTransition()
    {
        transitioningToNextLevel = true;
    }

    public function getRespawnCave():Cave
    {
        return this.respawnCave;
    }

    public function setRespawnCave(cave:Cave):Void
    {
        this.respawnCave = cave;
    }

    private function playerIsCalling():Bool
    {
        return this.player.isPlayerCalling();
    }

    public function callNearbyDinos(callRadius:Float):Void
    {   
        for (entity in entityGroups[EntityPrey])
        {   
            var prey:Prey = cast entity;
            var withinRange = GameWorld.entityDistance(player, prey) < callRadius;
            if (withinRange)
            {
                prey.addToHerd(player);
            }
        }
    }
}
