Player[] Players( maxClients );

const int CHASE_NONE = 0;
const int CHASE_FREE = 1;
const int CHASE_FIXED = 2;
const int CHASE_FOLLOW = 3;
const int CHASE_RESET = 4;

Cvar fb_airdash("fb_airdash", "0", 0);
Cvar fb_jetpack("fb_jetpack", "1", 0);

class Player
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

	uint kickTimestamp;
	float kickCharge;

	uint chase_timestamp = 0;
	bool chase_pressed = false;
	int chase_state;

	Player()
	{
		this.chase_state = CHASE_NONE;
	}
	~Player(){}

	void Update()
	{
        if ( player.isGhosting() )
        {
        	this.Ghosting();
        } else {
            this.notGhosting();
        }
	}

	void notGhosting()
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



		if ( client.pressedKeys & 16 == 16 && kickTimestamp <= levelTime && futsball.state != FB_ROUND_PREROUND )
		{
			Vec3 origin = player.origin;
			origin.z += player.viewHeight;
			if ( InRange() )
			{
				Vec3 fwd, right, up;
				player.angles.angleVectors(fwd, right, up);
				fwd.normalize();
				float kick = fb_maxspeed.value;
				if ( kickCharge < 100 )
					kick *= 1.0;
				else 
					kick *= 2.0;

				float movement_boost = (fwd * player.velocity) / 1000;
				if ( movement_boost > 1 )
					movement_boost = 1;
				if ( movement_boost < -1 )
					movement_boost = -1;

				kick *= (0.9+movement_boost/10.0);

				//G_CenterPrintMsg(player, "knockback: "+kick);
				FB_Ball.Knockback(fwd, kick);
				kickTimestamp = levelTime + 1000;
				@FB_Ball.lastHit = @client;
				G_PositionedSound(FB_Ball.collider.origin, CHAN_FIXED, G_SoundIndex("sounds/futsball/ball_hit_1.ogg"), 0.25);

			}
			kickCharge = 0;
		} else {
			kickCharge += 0.8;
			if ( kickCharge > 100 )
			{
				kickCharge = 100;
			}
		}
		player.health = 0.1+kickCharge;


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

	void Ghosting()
	{
		if ( player.team == TEAM_SPECTATOR )
		{
			//G_CenterPrintMsg(player, "chase_state: "+chase_state);
			if ( client.chaseActive && chase_state != CHASE_NONE )
			{
				client.chaseActive = false;
			}
			if ( !client.chaseActive )
			{
				bool new_chase_pressed = ( client.pressedKeys & 16 == 16 );
				if ( new_chase_pressed && !chase_pressed )
				{
					chase_state++;
				}
				chase_pressed = new_chase_pressed;

				switch (chase_state)
				{
					case CHASE_FREE:
					{
						// normal freefly camera, ignore
					}
					break;
					case CHASE_FIXED:
					{
						float chase_rate = 0.01;
						player.origin = player.origin*(1.0-chase_rate) + Vec3(0, 2000, 1200)*chase_rate;

						Vec3 direction = Vec3(FB_Ball.main.origin.x,0,-1000) - player.origin;
						direction.normalize();
						Vec3 player_dir, right, up;
						player.angles.angleVectors(player_dir, right, up);
						player_dir = player_dir*(1.0-chase_rate) + direction*chase_rate;
						player.angles = direction.toAngles();

						player.moveType = MOVETYPE_NONE;
					}
					break;
					case CHASE_FOLLOW:
					{
						float chase_rate = 0.05;
						Trace tr;
						float range = 200;

						Vec3 ball_dir = FB_Ball.main.velocity;
						ball_dir.z = -0.01;
						ball_dir.normalize();

						Vec3 b_origin = FB_Ball.main.origin;

						Vec3 chase_dest = Vec3(b_origin);
						chase_dest -= range * ball_dir;
						chase_dest.z += 100;

						tr.doTrace(b_origin, Vec3(-4,-4,-4), Vec3(4, 4, 4), chase_dest, player.entNum, MASK_SOLID);
						if ( tr.fraction != 1.0 )
						{
							Vec3 stop = tr.endPos;
							stop.z += (1.0-tr.fraction) * 32;
							tr.doTrace(b_origin, Vec3(-4,-4,-4), Vec3(4, 4, 4), stop, player.entNum, MASK_SOLID);
							chase_dest = tr.endPos;
						}

						player.origin = player.origin*(1.0-chase_rate) + chase_dest*chase_rate;
						Vec3 player_dir, right, up;
						player.angles.angleVectors(player_dir, right, up);
						player_dir = player_dir*(1.0-chase_rate) + ball_dir*chase_rate;
						player.angles = player_dir.toAngles();

						player.moveType = MOVETYPE_NONE;
					}
					break;
					case CHASE_RESET:
					{
						chase_state = CHASE_NONE;
						chase_timestamp = levelTime + 500;
						client.chaseActive = true;
						//player.moveType = MOVETYPE_NOCLIP;
					}
					break;
					default: break;
				}
			}

		}
	}
}