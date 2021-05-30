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
import flixel.system.FlxSound;
import flixel.graphics.FlxGraphic;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import flixel.FlxCamera;

class PlayState extends FlxState
{
    // A singleton reference to the global PlayState.
    public static var world:PlayState;

    static public final SCREEN_WIDTH = 800;
    static public final SCREEN_HEIGHT = 600;

    // Size of tiles/chunks
    static public final TILE_SIZE = 16;
    static public final CHUNK_WIDTH = 400;
    static public final CHUNK_HEIGHT = 300;

    // Enables debug commands (spawn prey, next level)
    static public final DEBUG = false;

    // Makes player move faster
    static public final DEBUG_FAST_SPEED = false;

    // Update every time update() is called.
    var frameCounter:Int = 0;

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

    // A group containing all collidable entities
    var collidableSprites:FlxGroup;
    var staticCollidableSprites:FlxGroup;

    // The object that holds the ogmo map.
    var map:FlxOgmo3Loader;

    // The tilemaps generated from the ogmo map.
    var ground:FlxTilemap;
    var obstacles:FlxTilemap;

    var respawnCave:Cave;

    var livesText:FlxText;
    var livesSprite:FlxSprite;

    // The level's score
    var scoreText:FlxText;
    var scoreSecondaryText:FlxText;

    // Screen transition
    var transitioningToNextLevel:Bool = false;
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
    public var numPredatorsCollected:Int = 0;
    public var numPrey:Int = 0;

    var lastDeliveredTimer:Float = 0.0;

    var cameraZoomDirection:Int = -1;
    var cameraZoomTween:FlxTween;

    var initialCameraZoomTween:FlxTween;

    var predatorAlarmClock:FlxTimer;

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

        for (type in Type.allEnums(EntityType))
        {
            entityGroups[type] = new Array<Entity>();
            spriteGroups[type] = new FlxGroup();
        }

        GameWorld.getABChoice();

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
            add(tutorialText);
        }

        var nextMap = GameWorld.getNextMap();
        if (nextMap == null)
        {
            // Go to game win screen!
            dead = true;
            MenuPlayState.menuState = GameWinState;
            FlxG.switchState(new MenuPlayState());
            return;
        }
        
        // Set up the tilemap.
        map = new FlxOgmo3Loader(AssetPaths.DinoHerder__ogmo, nextMap);

        // Static Entities.
        // Load tiles from tile maps
        ground = map.loadTilemap(AssetPaths.Tileset__png, "ground");
        ground.useScaleHack = true;
        add(ground);

        obstacles = map.loadTilemap(AssetPaths.Tileset__png, "obstacles");
        ground.useScaleHack = true;
        mapWidth = obstacles.widthInTiles;
        mapHeight = obstacles.heightInTiles;
        add(obstacles);

        ground.health = bottomLayerSortIndex() - 1;
        obstacles.health = bottomLayerSortIndex() + 1;

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
        scoreText = new FlxText(0, 0, 0, "" + Score.getScore(), 24);
        scoreText.scrollFactor.x = scoreText.scrollFactor.y = 0;
        scoreText.x = overlayCamera.width - scoreText.width - 16;
        scoreText.y = 8;
        scoreText.setBorderStyle(SHADOW, FlxColor.BLACK, 3, 1);
        scoreText.health = topLayerSortIndex() + 2;
        scoreText.camera = overlayCamera;
        add(scoreText);
        
        scoreSecondaryText = new FlxText(0, 0, 0, null, 15);
        scoreSecondaryText.scrollFactor.x = scoreSecondaryText.scrollFactor.y = 0;
        scoreSecondaryText.x = overlayCamera.width - scoreSecondaryText.width - 16;
        scoreSecondaryText.y = scoreText.y + scoreText.height + 1;
        scoreSecondaryText.setBorderStyle(SHADOW, FlxColor.BLACK, 2, 1);
        scoreSecondaryText.health = topLayerSortIndex() + 2;
        scoreSecondaryText.camera = overlayCamera;
        add(scoreSecondaryText);

        livesText = new FlxText(16, 8, 0, "" + Player.getLives() + " x ", 24);
        livesText.scrollFactor.x = livesText.scrollFactor.y = 0;
        livesText.setBorderStyle(SHADOW, FlxColor.BLACK, 3, 1);
        livesText.health = topLayerSortIndex() + 2;
        livesText.camera = overlayCamera;
        add(livesText);

        livesSprite = new FlxSprite(livesText.x + livesText.width - 4, 12);
        livesSprite.loadGraphic(AssetPaths.heart_big__png, 27, 24);
        livesSprite.health = topLayerSortIndex() + 2;
        livesSprite.camera = overlayCamera;
        add(livesSprite);

        // Set up transition screen
        transitionScreen = new FlxSprite(0, 0);
        transitionScreen.makeGraphic(SCREEN_WIDTH, SCREEN_HEIGHT, FlxColor.BLACK);
        transitionScreen.alpha = 1;
        transitionScreen.health = topLayerSortIndex() + 10;
        transitionScreen.camera = overlayCamera;
        add(transitionScreen);

        this.persistentDraw = true;
        this.persistentUpdate = true;

        var levelIndex = GameWorld.levelId();
        PlayLogger.startLevel(levelIndex);
        Predator.updateAggression();
        if (levelIndex > 4)
        {
            var adjustment = 0.1 + levelIndex * 0.05;
            Predator.adjustAggression(adjustment);
        }

        this.predatorAlarmClock = new FlxTimer();
        predatorAlarmClock.start(5.0, function (timer) 
            {
                var newTime = GameWorld.map(0.0, 1.0, 20.0, 8.0, Predator.aggression);
                predatorAlarmClock.reset(newTime);
                
                for (entity in entityGroups[EntityPredator])
                {
                    var predator:Predator = cast entity;
                    if (predator.getState() == Sleeping) 
                    {
                        predator.wakeUp();
                        return;
                    }
                }
                predatorAlarmClock.cancel();
            }, 0);
    }

    function baseZoom():Float
    {
        return SCREEN_WIDTH / CHUNK_WIDTH;
    }

    function minZoom():Float
    {
        return baseZoom() * 0.7;
    }

    var overlayCamera:FlxCamera;
    function setupCamera()
    {
        // Set world size
        FlxG.worldBounds.set(0, 0, TILE_SIZE * mapWidth, TILE_SIZE * mapHeight);
        
        overlayCamera = new FlxCamera(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 1.0);
        overlayCamera.bgColor = FlxColor.TRANSPARENT;
        FlxG.cameras.add(overlayCamera, false);

        // Set camera to follow player
        FlxG.camera.setScrollBoundsRect(0, 0, TILE_SIZE * mapWidth, TILE_SIZE * mapHeight);
        FlxG.camera.zoom = 1.0;
        FlxG.camera.bgColor = 0xFF6DBAB8;
        FlxG.camera.follow(player.getSprite(), TOPDOWN, 0.2);

        var camera_x = SCREEN_WIDTH/2;
        var camera_y = SCREEN_HEIGHT/2;
        var camera_w = CHUNK_WIDTH/5;
        var camera_h = CHUNK_HEIGHT/5;
        FlxG.camera.deadzone.set(camera_x - camera_w/2, camera_y - camera_h/2, camera_w, camera_h);

        var duration = 5.0;
        var options = {ease: FlxEase.cubeInOut, onComplete: function (tween) {
            initialCameraZoomTween = null;
        }};

        var initialZoom:Float;
        if (mapWidth < mapHeight)
        {
            initialZoom = SCREEN_WIDTH / (mapWidth * 16);
        }
        else
        {
            initialZoom = SCREEN_HEIGHT / (mapHeight * 16);
        }
        initialCameraZoomTween = FlxTween.num(initialZoom, baseZoom(), duration, options, function (f: Float) {
            FlxG.camera.zoom = f;
        });
    }

    function createTileCollider(tileX:Int, tileY:Int, obstacles:FlxTilemap)
    {
        var tileNum = obstacles.getTile(tileX, tileY);
        if (tileNum == 0) return;

        var obstacle = TileType.getTileObstacle(tileNum);
        if (obstacle == null)
        {
            // This tile doesn't need a custom hitbox. Keep it in the tilemap.
        }
        else
        {
            var sprite = obstacle.getSprite();
            var x = tileX * TILE_SIZE + TILE_SIZE/2 - sprite.width/2;
            var y = tileY * TILE_SIZE + TILE_SIZE/2 - sprite.height/2;
            
            if (TileType.nonCollidable(tileNum))
            {
                if (obstacle.collides())
                {
                    obstacles.setTile(tileX, tileY, TileType.TRANSPARENT_COLLIDE);
                }
                else
                {
                    obstacles.setTile(tileX, tileY, TileType.TRANSPARENT_NO_COLLIDE);
                }

                if (TileType.isStatic(tileNum))
                {
                    staticCollidableSprites.add(sprite);
                }
                else
                {
                    collidableSprites.add(sprite);
                }
            }

            obstacle.setPosition(x, y);
            add(sprite);
        }
    }

    public function nextLevel()
    {
        PlayLogger.endLevel();

        if (this.numPrey == 0)
        {
            // There are no prey on this level, so skip displaying the score.
            FlxG.switchState(new PlayState());
            return;
        }
        else
        {
            FlxG.switchState(new TransitionState());
        }
    }

    function updateTransitionScreen()
    {
        // Check to load next level.
        transitioningToNextLevel = player.isInRangeOfCave() && levelIsComplete();
        if (GameWorld.levelId() == 1)
        {
            transitioningToNextLevel = false;
        }

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
            closeLevelMenu();
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

    function updateCamera()
    {
        if (initialCameraZoomTween != null) return;

        var duration = 2.5;
        var zoom = FlxG.camera.zoom;
        if (player.isPlayerCalling())
        {
            if (zoom > minZoom() && cameraZoomDirection == -1)
            {
                var options = {ease: FlxEase.expoOut, onComplete: function (tween) {
                    cameraZoomTween = null;
                }};
                
                if (cameraZoomTween != null) cameraZoomTween.cancel();
                cameraZoomTween = FlxTween.num(zoom, minZoom(), duration, options, function (f: Float) {
                    FlxG.camera.zoom = f;
                });
                cameraZoomDirection = 1;
            }
        }
        else
        {
            if (zoom < baseZoom() && cameraZoomDirection == 1)
            {
                var options = {ease: FlxEase.expoOut, onComplete: function (tween) {
                    cameraZoomTween = null;
                }};
                
                if (cameraZoomTween != null) cameraZoomTween.cancel();
                cameraZoomTween = FlxTween.num(zoom, baseZoom(), duration, options, function (f: Float) {
                    FlxG.camera.zoom = f;
                });
                cameraZoomDirection = -1;
            }
        }
    }

    function updateScore()
    {
        livesText.text = "" + Player.getLives() + " x ";
        livesSprite.x = livesText.x + livesText.width - 4;

        Score.update();
        var score = Score.getScore();
        if (score != lastScore)
        {
            function setAlpha(f:Float) {
                scoreSecondaryText.alpha = f;
            }
            scoreSecondaryText.text = "+" + (score - lastScore);
            scoreSecondaryText.x = overlayCamera.width - scoreSecondaryText.width - 16;
            var details = { ease: FlxEase.expoIn, onComplete: function(tween) {
                scoreText.text = "" + score;
                scoreText.x = overlayCamera.width - scoreText.width - 16;

                new FlxTimer().start(1.0, function (timer) {
                    var details = { ease: FlxEase.expoIn };
                    FlxTween.num(1.0, 0.0, 0.3, details, setAlpha);
                });
            }};
            FlxTween.num(0.0, 1.0, 0.3, details, setAlpha);

            lastScore = score;
        }
    }

    var lastScore:Int = Score.getScore();
    var dead:Bool = false;

    override public function update(elapsed:Float)
    {
        if (dead)
        {
            return;
        }

        if (!PlayLogger.loggerInitialized())
        {
            // Don't execute update method until logger session has been created.
            return;
        }

        if (DEBUG)
        {
            // Debug commands for skipping to game over/game win
            if (FlxG.keys.anyPressed([K]))
            {
                MenuPlayState.menuState = GameOverState;
                FlxG.switchState(new MenuPlayState());
                return;
            }
            if (FlxG.keys.anyPressed([L]))
            {
                MenuPlayState.menuState = GameWinState;
                FlxG.switchState(new MenuPlayState());
                return;
            }
        }

        PlayLogger.update();
        PlayLogger.incrementTime(elapsed);

        // Do collision checks
        // Don't do collision checks on the very first frame of execution. This prevents weird spawning in bugs.
        if (frameCounter > 0)
        {
            collisionChecks();
        }
 
        updateTransitionScreen();
        updateCamera();
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

        if (frameCounter == 0)
        {
            FlxG.camera.snapToTarget();
        }

        lastDeliveredTimer -= elapsed;
        scoreSoundMultiplier -= 0.005;
        frameCounter++;

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

    // Adds entity to the world and respective sprite group.
    public function addEntity(entity:Entity)
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
        collidableSprites.add(sprite);
    }

    public function removeEntity(entity:Entity)
    {
        entity.dead = true;
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
            remove(entity.getThought().sprite, true);
        }
    }

    public function removeFromCollidableSprites(entity:Entity)
    {
        collidableSprites.remove(entity.getSprite());
    }

    function collisionChecks()
    {
        // Collision resolution

        // Check collidable entity overlap
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
        visionChecks();
    }

    function visionChecks()
    {
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


        if (!hasSeenNewEntity && newEntity != EntityNull)
        {
            for (entity in entityGroups[newEntity])
            {
                //var visionCheck = GameWorld.checkVision(player, entity)) // and in range
                if (GameWorld.entityDistance(player, entity) < player.getSightRange())
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
        // Enable/Disable collisions (these collisions are used when raycasting).
        var collisions = toggle ? FlxObject.ANY : FlxObject.NONE;
        obstacles.setTileProperties(TileType.TRANSPARENT_COLLIDE, collisions);
    }

    function placeEntities(entity:EntityData)
    {
        var x = entity.x;
        var y = entity.y;

        switch (entity.name)
        {
            case "player":
                player = new Player();
                player.setPosition(x, y);
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
                cave.setPosition(x - TILE_SIZE, y - 2 * TILE_SIZE);
                addEntity(cave);
            case "boulder":
                var boulder = new Boulder();
                boulder.setPosition(x, y);
                addEntity(boulder);
        }
    }

    function handleCollision(s1:SpriteWrapper<Entity>, s2:SpriteWrapper<Entity>)
    {
        if (Std.is(s2, SpriteWrapper) && Std.is(s2, SpriteWrapper))
        {
            var e1 = s1.entity;
            var e2 = s2.entity;

            e1.handleCollision(e2);
            e2.handleCollision(e1);
        }
        else
        {
            Console.log("handleCollision() : UNEXPECTED TYPE");
        }
    }

    function handleSeparationCollision(s1:SpriteWrapper<Entity>, s2:SpriteWrapper<Entity>)
    {
        var e1 = s1.entity;
        var e2 = s2.entity;
        e1.handleCollision(e2);
        e2.handleCollision(e1);

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
        else if (e1.collides() && e2.collides())
        {
            // Only separate them if the other conditions are not met.
            FlxObject.separate(s1, s2);
        }
    }

    public function getCaves()
    {
        return entityGroups[EntityCave];
    }

    function levelIsComplete()
    {
        return entityGroups[EntityPrey].length == 0;
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

        for (entity in entityGroups[EntityPredator])
        {
            var predator:Predator = cast entity;
            var withinRange = GameWorld.entityDistance(player, predator) < callRadius;
            if (withinRange)
            {
                predator.track(player);
            }
        }
    }

    public function levelFinished()
    {
        return entityGroups[EntityPrey].length == 0;
    }

    var scoreSoundMultiplier:Float = 0.0;
    public function collectDino(dino:Dino, cave:Cave)
    {
        if (!dino.dead)
        {
            closeLevelMenu();
            lastDeliveredTimer = 1.0;

            dino.dead = true;

            var numPreyLeft = 0;
            if (dino.getType() == EntityPrey)
            {
                for (prey in entityGroups[EntityPrey])
                {
                    if (!prey.dead)
                        numPreyLeft++;
                }
                cave.think("" + numPreyLeft, 3.5, true);
            }
            else
            {
                cave.think("!?", 2.5, true);
            }

            Score.collectDino(dino);
            dino.getSprite().health = bottomLayerSortIndex() + 1;
            dino.fadeOutAndRemove();

            scoreSoundMultiplier += 0.1;
            if (scoreSoundMultiplier > 0.4) scoreSoundMultiplier = 0.4;
            if (scoreSoundMultiplier < 0) scoreSoundMultiplier = 0;

            FlxG.sound.play(AssetPaths.scoreSound__mp3, 0.15 + scoreSoundMultiplier);

            if (dino.getType() == EntityPrey)
            {
                Predator.adjustAggression(0.01);
                numPreyCollected++;
            }
            else if (dino.getType() == EntityPredator)
            {
                Predator.adjustAggression(0.1);
                numPredatorsCollected++;
            }
        }
    }

    public function getNumPreyLeft():Int
    {
        return entityGroups[EntityPrey].length;
    }

    public function getNumPredatorsLeft():Int
    {
        return entityGroups[EntityPredator].length;
    }



    public function getPlayer():Player
    {
        return this.player;
    }

    public var levelMenu:LevelMenuState;
    public function openLevelMenu(cave:Cave)
    {
        if (lastDeliveredTimer <= 0 && levelMenu == null)
        {
            levelMenu = new LevelMenuState(cave.getX(), cave.getY());
            openSubState(levelMenu);
        }
    }

    public function closeLevelMenu()
    {
        if (levelMenu != null)
        {
            levelMenu.closeMenu();
        }
        else
        {
            closeSubState();
        }
    }

    var gameOver:Bool = false;
    public function gameOverScreen()
    {
        if (!gameOver)
        {
            gameOver = true;
            camera.shake(0.012, 0.3);
            camera.fade(0xFF800000, 0.6, false, function() {
                MenuPlayState.menuState = GameOverState;
                FlxG.switchState(new MenuPlayState());
            }, true);
        }
    }

    public function isDebug()
    {
        return DEBUG;
    }
}
