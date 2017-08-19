Cvar fb_airdash("fb_airdash", "0", 0);
Cvar fb_jetpack("fb_jetpack", "1", 0);

Jetpack[] jetpacks(maxClients);

class Jetpack
{
	Client@ client;
	Entity@ player;
	Entity@ jetpack;
	bool jetpackActive = false;
	uint dashTimestamp;
	bool canDash = false;
	bool hasDashed = false;
	bool dashPressed = false;
	bool isOnGround = true;

	uint gbTimeStamp;
	float gbCharge;
	bool gbPressed = false;
	bool inrange = false;
	uint rangesoundloop;

	Jetpack()
	{
	}

	~Jetpack(){}

	void Update()
	{
		if ( @this.jetpack == null )
		{
			@this.jetpack = @G_SpawnEntity("jetpack");
			this.jetpack.sound = G_SoundIndex("sounds/futsball/jetpack_mid.ogg");
			this.jetpack.attenuation = ATTN_NORM;
			this.jetpack.moveType = MOVETYPE_FLY;

			this.jetpack.type = ET_PARTICLES;
			this.jetpack.particlesSpeed = 0;
			this.jetpack.particlesShaderIndex = G_ImageIndex("gfx/misc/smokepuff");
			this.jetpack.particlesSpread = 100;
			this.jetpack.particlesSize = 8;
			this.jetpack.particlesTime = 1;
			this.jetpack.particlesFrequency = 100;
			this.jetpack.particlesSpherical = false;
			this.jetpack.particlesBounce = false;
			this.jetpack.particlesGravity = true;
			this.jetpack.particlesExpandEffect = true;
			this.jetpack.particlesShrinkEffect = false;


			this.jetpack.linkEntity();
		}

		this.jetpack.team = player.team;


		bool new_dashPressed = false;
		if ( client.pressedKeys & 128 == 128 )
			new_dashPressed = true;

		bool new_isOnGround = true;
		if ( @player.groundEntity == null )
			new_isOnGround = false;


		/*if ( !inrange && InRange() )
		{
			inrange = true;
			rangesoundloop = 0;
		}
		if ( inrange && !InRange() )
		{
			inrange = false;
			G_LocalSound(client, CHAN_MUZZLEFLASH, G_SoundIndex("sounds/futsball/empty.ogg"));
		}
		if ( inrange && rangesoundloop <= levelTime )
		{
			G_LocalSound(client, CHAN_MUZZLEFLASH, G_SoundIndex("sounds/futsball/ball_close_0.ogg"));

			rangesoundloop = levelTime + 6000;
		}*/



		if ( @player.groundEntity == null )
		{
			client.pmoveFeatures = client.pmoveFeatures & ~PMFEAT_CROUCH;
		} else {
			client.pmoveFeatures = client.pmoveFeatures | PMFEAT_CROUCH;
		}

		if ( InRange() )
			client.armor = 100;
		else
			client.armor = 0;



		if ( client.pressedKeys & 16 == 16 && gbTimeStamp <= levelTime && futsball.state != FB_ROUND_PREROUND )
		{
			Vec3 origin = player.origin;
			origin.z += player.viewHeight;
			if ( InRange() )
			{
				Vec3 fwd, right, up;
				player.angles.angleVectors(fwd, right, up);
				fwd.normalize();
				float kick = fb_maxspeed.value;
				if ( gbCharge < 100 )
					kick *= 1.0;
				else 
					kick *= 2.0;

				float movement_boost = (fwd * player.velocity) / 1000;
				if ( movement_boost > 1 )
					movement_boost = 1;
				if ( movement_boost < -1 )
					movement_boost = -1;

				kick *= (0.9+movement_boost/10.0);

				G_CenterPrintMsg(player, "knockback: "+kick);
				FB_Ball.Knockback(fwd, kick);
				gbTimeStamp = levelTime + 1000;
				@FB_Ball.lastHit = @client;
				G_PositionedSound(FB_Ball.collider.origin, CHAN_FIXED, G_SoundIndex("sounds/futsball/ball_hit_1.ogg"), 0.25);

			}
			gbCharge = 0;
		} else {
			gbCharge += 0.8;
			if ( gbCharge > 100 )
			{
				gbCharge = 100;
			}
		}
		player.health = 0.1+gbCharge;


		if ( fb_jetpack.boolean )
		{
			Vec3 origin = player.origin;
			origin.z += player.viewHeight;

			this.jetpack.origin = origin;
			this.jetpack.velocity = player.velocity;

			if ( !(@player.groundEntity != null && client.pressedKeys & 64 == 64) && futsball.state != FB_ROUND_PREROUND )
			{
				Vec3 vel = player.velocity;
				bool active = false;
				if ( client.pressedKeys & 32 == 32 )
				{
					vel.z += 20;
					active = true;
				}

				if ( client.pressedKeys & 64 == 64 )
				{
					vel.z -= 20;
					active = true;
				}

				player.velocity = vel;
				if ( !this.jetpackActive && active )
				{
					G_PositionedSound(origin, CHAN_AUTO, G_SoundIndex("sounds/futsball/jetpack_start.ogg"), ATTN_NORM);
				} else if ( this.jetpackActive && !active )
				{
					G_PositionedSound(origin, CHAN_AUTO, G_SoundIndex("sounds/futsball/jetpack_end.ogg"), ATTN_NORM);
				}
				this.jetpackActive = active;
			} else {
				if ( this.jetpackActive )
				{
					G_PositionedSound(origin, CHAN_AUTO, G_SoundIndex("sounds/futsball/jetpack_end.ogg"), ATTN_NORM);
				}
				this.jetpackActive = false;
			}

			if ( this.jetpackActive )
			{
				this.jetpack.svflags &= ~SVF_NOCLIENT;
			} else {
				this.jetpack.svflags |= SVF_NOCLIENT;
			}
		}

		// air dash

		if ( fb_airdash.boolean )
		{
			if ( new_isOnGround )
			{
				canDash = false;
				hasDashed = false;
				dashTimestamp = levelTime + 300;
			}

			if ( dashTimestamp <= levelTime )
			{
				if ( !new_dashPressed )
				{
					canDash = true;
				}
			}

			if ( !hasDashed && canDash && !dashPressed && new_dashPressed )
			{
				Vec3 fwd, right, up;
				player.angles.angleVectors(fwd, right, up);
				fwd.z = 0;
				right.z = 0;
				fwd.normalize();
				right.normalize();
				Vec3 vel = player.velocity;
				vel.z = 0;
				Vec3 vfwd, vright, vup;
				vel.toAngles().angleVectors(vfwd, vright, vup);

				float btn_fwd = 0;
				float btn_right = 0;
				if ( client.pressedKeys & 1 == 1 )
					btn_fwd += 1;
				if ( client.pressedKeys & 2 == 2 )
					btn_fwd -= 1;
				if ( client.pressedKeys & 4 == 4)
					btn_right -= 1;
				if ( client.pressedKeys & 8 == 8 )
					btn_right += 1;

				if ( btn_fwd == 0 && btn_right == 0)
					btn_fwd = 1;

				float len = vel.length();
				if ( len < 1000 )
					len = 1000;
				vel = (btn_fwd*fwd + btn_right*right) * len;
				vel.z = 32;
				player.velocity = vel;
				canDash = false;
				hasDashed = true;
			}


		}
		dashPressed = new_dashPressed;
		isOnGround = new_isOnGround;
	}

	bool InRange()
	{
		Vec3 origin = player.origin;
		origin.z += player.viewHeight;
		Vec3 porigin = player.origin;
		porigin.z += player.viewHeight;
		Vec3 fwd, right, up;
		player.angles.angleVectors(fwd, right, up);
		fwd.normalize();
		origin -= fwd*100;
		Vec3 direction = FB_Ball.collider.origin - origin;
		direction.normalize();

		//float distance = (origin+fwd).distance(origin+direction);

		float angle = fwd*direction;
		//G_CenterPrintMsg(player, ""+angle);
		return ( angle > 0 && porigin.distance(FB_Ball.collider.origin) < 300 );
	}
}