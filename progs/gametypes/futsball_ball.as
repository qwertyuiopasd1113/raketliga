Ball FB_Ball;
Vec3 Ball_Spawn;
const float pi = 3.141592f;

Cvar fb_knockback("fb_knockback", "0.5", 0);	// knockback multiplier
Cvar fb_bounce("fb_bounce", "0.7", 0);			// bounce multiplier
Cvar fb_friction("fb_friction", "0.97", 0);		// "slide" multiplier
Cvar fb_gravity("fb_gravity", "0.15", 0);		// downward velocity per update
Cvar fb_stop("fb_stop", "0.0", 0);				// stopping threshold
Cvar fb_maxspeed("fb_maxspeed", "32.0", 0);		// max speed
Cvar fb_touch("fb_touch", "0", 0);				// do player touch kick stuff
Cvar fb_touchkick("fb_touchkick", "50", 0);		// touch kick amount
Cvar fb_touchminkick("fb_touchminkick", "10", 0); // minimum touch kick amount
Cvar fb_touchspeed("fb_touchspeed", "750", 0); // touch player velocity kick multiplier bla
Cvar fb_touchoffset("fb_touchoffset", "8", 0);  // touch collision box offset
Cvar fb_noclip("fb_noclip", "1", 0);  			// ball vs player noclip

void target_ball( Entity@ ent )
{
	Ball_Spawn = ent.origin;
}

void FB_SpawnBall( Entity@ ent )
{
	FB_Ball = Ball(@ent, 64);
}

class Ball
{
	Vec3 spawner;
	Entity@ main;
	Entity@ collider;
	Entity@ touchcollider;
	Entity@ particles;
	Entity@ indicator;
	Entity@ groundEntity;
	Entity@ inflictor;
	Vec3 groundNormal;
	Client@ lastHit;
	float radius;
	int delay;
	bool scored = false;
	bool hover = false;

	Ball(Entity@ ball, float radius)
	{
		this.radius = radius;
		this.spawner = ball.origin;
		if ( Ball_Spawn != Vec3() )
			this.spawner = Ball_Spawn;

		@this.main = @G_SpawnEntity("ball");
		this.main.setupModel("*" + ball.modelindex);
		this.main.svflags &= ~SVF_NOCLIENT;
		this.main.linkEntity();

		@this.collider = @G_SpawnEntity("ball_collider");
		this.InitCollider(this.collider);

		@this.touchcollider = @G_SpawnEntity("ball_collider");
		this.touchcollider.solid = SOLID_TRIGGER;
		this.touchcollider.setSize(
			Vec3(-radius-fb_touchoffset.value, -radius-fb_touchoffset.value, -radius-fb_touchoffset.value),
			Vec3( radius+fb_touchoffset.value,  radius+fb_touchoffset.value,  radius+fb_touchoffset.value)
		);
		this.touchcollider.origin = this.main.origin;
		this.touchcollider.velocity = this.main.velocity;
		@this.touchcollider.touch = FB_Ball_Touch;

		@this.particles = @G_SpawnEntity("ball_particles");
		this.particles.svflags &= ~SVF_NOCLIENT;
		this.particles.type = ET_PARTICLES;
		this.particles.particlesSpeed = 0;
		this.particles.particlesShaderIndex = G_ImageIndex("textures/msc/futsball/trail");
		this.particles.particlesSpread = 0;
		this.particles.particlesSize = int(radius);
		this.particles.particlesTime = 1;
		this.particles.particlesFrequency = 255;
		this.particles.particlesSpherical = false;
		this.particles.particlesBounce = false;
		this.particles.particlesGravity = false;
		this.particles.particlesExpandEffect = false;
		this.particles.particlesShrinkEffect = false;
		this.particles.linkEntity();

		@this.indicator = @G_SpawnEntity("ball_indicator");
		this.indicator.type = ET_DECAL;
		this.indicator.solid = SOLID_NOT;
		this.indicator.origin2 = Vec3(0,0,1);
		this.indicator.modelindex = G_ImageIndex( "textures/msc/futsball/indicator" );
		this.indicator.modelindex2 = 0;
		this.indicator.svflags = ( this.indicator.svflags & ~SVF_NOCLIENT ) | SVF_TRANSMITORIGIN2;
		this.indicator.frame = int(radius*2);
		this.indicator.linkEntity();

		this.resetPos(0.0);


		ball.unlinkEntity();
		ball.freeEntity();

	}
	~Ball() {}

	void resetPos(float speed)
	{
		Vec3 vel = Vec3(brandom(-1,1), brandom(-1,1), brandom(-1,1));
		vel.normalize();
		vel *= speed;

		this.main.origin = spawner;
		this.main.velocity = vel;
		this.collider.origin = spawner;
		this.collider.velocity = vel;
		this.touchcollider.origin = spawner;
		this.touchcollider.velocity = vel;
		this.particles.origin = spawner;
		this.particles.velocity = vel;

		@this.groundEntity = null;
		this.groundNormal = Vec3();
		this.UpdateIndicator();
	}

	void InitCollider(Entity @ent)
	{
		//ent.solid = SOLID_YES;
		ent.setSize(
			Vec3(-radius, -radius, -radius),
			Vec3( radius,  radius,  radius)
		);
		ent.clipMask = MASK_ALL;
		ent.nextThink = levelTime + 1;
		ent.health = 100000;
		//ent.takeDamage = DAMAGE_AIM;
		//@ent.touch = FB_Ball_Touch;
		ent.svflags &= ~SVF_NOCLIENT;
		ent.svflags |= SVF_BROADCAST;
		@ent.pain = FB_Ball_Pain;
		@ent.die = FB_Ball_Die;
		@ent.think = FB_Ball_Think;
		ent.moveType = MOVETYPE_FLY;
		ent.origin = this.main.origin;
		ent.velocity = this.main.velocity;
		ent.linkEntity();
	}

	void Update()
	{
		if ( futsball.state == FB_ROUND_PREROUND )
		{
			return;
		}

		/*if ( this.log )
		{
			G_Print("update "+levelTime+"\n");
			this.log = false;
		}*/

		//goal delay & reset
		if ( match.getState() == MATCH_STATE_WARMUP )
		{
			if ( delay > 0 && scored )
			{
				delay -= frameTime;
			}
			if ( delay <= 0 && scored )
			{
				scored = false;
				resetPos(0);
				/*for ( uint i = 0; i < uint(maxClients); i++ )
				{
					Client@ client = @G_GetClient(i);
					if ( @client != null && client.team != TEAM_SPECTATOR )
						client.respawn(false);
				}*/
			}
		}

		Vec3 vel = main.velocity;
		Vec3 origin = main.origin;

		// reset ball if out of bounds
		if ( origin.length() > 5120 || origin.z < 0 )
			this.resetPos(0);

		origin += vel;

		// gravity
		if ( @this.groundEntity == null )
			vel.z -= fb_gravity.value;
		else
			return;

		Vec3 planeNormal;
		Vec3 offset;
		int entNum = 0;
		int count = 0;

		float step = pi / 8;
		Trace tr;
		for ( float theta = 0; theta <= pi; theta += step )
		{
			for ( float phi = -pi; phi < pi; phi += step )
			{
				offset = Vec3(
					sin(theta) * cos(phi),
					sin(theta) * sin(phi),
					cos(theta)
				);
				offset.normalize();

				tr.doTrace( origin, Vec3(), Vec3(), origin + offset*radius*8.0, collider.entNum, MASK_PLAYERSOLID );
				if ( origin.distance(tr.endPos) < radius && !( fb_noclip.boolean && tr.contents == CONTENTS_BODY ) )
				{
					origin += tr.planeNormal*((origin+offset*radius).distance(tr.endPos));
					planeNormal += tr.planeNormal;
					entNum = tr.entNum;
					count++;
				}
			}
		}
		if ( count != 0 )
		{
			planeNormal.normalize();

			float velDotPlane = abs(vel * planeNormal);
			vel += planeNormal * (1.0+fb_bounce.value)* velDotPlane;
			vel *= fb_friction.value;
			if ( abs(vel.z) < fb_stop.value && planeNormal.z > 0.9 )
			{
				vel = Vec3();
				this.groundNormal = planeNormal;
				@this.groundEntity = @G_GetEntity(entNum);
			}

			if ( velDotPlane > 2.0 )
				G_PositionedSound( origin, CHAN_ITEM, G_SoundIndex("sounds/futsball/ball_bounce_" + int( brandom( 0, 12 ) ) ), 5.0/vel.length() );
		}

		//limit to radius speed
		if ( vel.length() > fb_maxspeed.value )
		{
			vel.normalize();
			vel *= fb_maxspeed.value;
		}

		//fake rotation
		main.avelocity = Vec3(-main.velocity.y, main.velocity.z, -main.velocity.x);
		Vec3 angles = main.angles;
		angles += (main.avelocity * (frameTime*0.01));
		main.angles = angles;

		this.main.velocity = vel;
		this.main.origin = origin;
		this.collider.velocity = vel;
		this.collider.origin = origin;
		this.collider.linkEntity();
		this.touchcollider.velocity = vel;
		this.touchcollider.origin = origin;
		this.touchcollider.linkEntity();
		this.particles.velocity = vel;
		this.particles.origin = origin;

		/*tr.doTrace( origin, Vec3(), Vec3(), origin - Vec3(0,0,2048), this.collider.entNum, MASK_PLAYERSOLID );
		this.indicator.origin = tr.endPos;
		Vec3 vel_indicator = Vec3(vel);
		vel_indicator.z = 0;
		this.indicator.velocity = vel_indicator;*/
		this.UpdateIndicator();

		//G_CenterPrintMsg(null, "speed: "+vel.length());
	}

	void UpdateIndicator()
	{
		Trace tr;
		tr.doTrace( collider.origin, Vec3(), Vec3(), collider.origin - Vec3(0,0,2048), this.collider.entNum, MASK_PLAYERSOLID );
		this.indicator.origin = tr.endPos;
		Vec3 vel_indicator = Vec3(collider.velocity);
		vel_indicator.z = 0;
		this.indicator.velocity = vel_indicator;
	}

	void Knockback( Vec3 dir, float kick )
	{
		Vec3 vel = main.velocity;
		dir.normalize();
		Vec3 knockback = dir * (kick * fb_knockback.value);

		if ( @this.groundEntity != null )
		{
			knockback += 2.0 * abs(knockback*this.groundNormal) * this.groundNormal;
		}

		float kb_len = knockback.length();
		float vel_len = vel.length();

		//vel += knockback;
		vel = (0.25*vel + 0.75*knockback);
		vel.normalize();

		vel *= kb_len + vel_len;

		//limit to radius speed
		if ( vel.length() > fb_maxspeed.value )
		{
			vel.normalize();
			vel *= fb_maxspeed.value;
		}

		this.main.velocity = vel;
		this.collider.velocity = vel;
		this.touchcollider.velocity = vel;
		this.particles.velocity = vel;
		Vec3 vel_indicator = Vec3(vel);
		vel_indicator.z = 0;
		this.indicator.velocity = vel_indicator;
		@this.groundEntity = null;
	}

	void Pain(Entity @ball, Entity @other, float kick, float damage)
	{
		if ( @other.client != null )
		{
			@this.lastHit = @other.client;
			//@this.collider.client = @other.client;
		}

		this.collider.health = 100000;

		Vec3 origin = other.origin;
		origin.z += other.viewHeight;
		/*if ( @this.inflictor.client != null )
		{
			//G_CenterPrintMsg(null, "pain "+levelTime+" hitscan\ninflictor: "+this.inflictor.client.name+"\n");
			origin.z += this.inflictor.viewHeight - 16;
			//G_CenterPrintMsg(null, "hitscan");
		} else {
			//G_CenterPrintMsg(null, "pain "+levelTime+" projectile\ninflictor: "+this.inflictor.classname+"\n");
			//G_CenterPrintMsg(null, "projectile");
		}*/

		Vec3 projectile_angle = other.angles;
		Vec3 fwd, right, up;
		projectile_angle.angleVectors(fwd, right, up);
		fwd.normalize();
		Vec3 dir = collider.origin-origin;
		float distance = dir.length();
		dir.normalize();

		Vec3 knockback = dir * kick * fb_knockback.value;

		Trace tr;
		tr.doTrace(origin, Vec3(), Vec3(), origin + fwd * (distance + radius*2), -1, MASK_SHOT);

		//temp entity for position
		Entity@ temp = @G_SpawnEntity("temp");
		temp.origin = tr.endPos;	
		temp.explosionEffect(16);
		temp.freeEntity();

		Vec3 trdir = collider.origin - tr.endPos;
		float trdist = trdir.length();
		bool hit = false;
		if ( tr.fraction < 1.0 )
		{
			if ( tr.entNum == ball.entNum || trdist < radius*1.1 )
				hit = true;
		}

		if ( hit )
		{
			//G_CenterPrintMsg(null, "HIT frac: "+tr.fraction+" entnum: "+tr.entNum+" dist: "+trdist);
			trdir.normalize();
			//knockback = trdir * kick * fb_knockback.value;
			this.Knockback( trdir, kick );
		} else {
			//G_CenterPrintMsg(null, "MISS frac: "+tr.fraction+" entnum: "+tr.entNum+" dist: "+trdist);
			this.Knockback( dir, kick );
		}

		/*if ( @this.groundEntity != null )
		{
			knockback += 2.0 * abs(knockback*this.groundNormal) * this.groundNormal;
		}

		Vec3 vel = collider.velocity;
		vel += knockback;

		//limit to radius speed
		if ( vel.length() > fb_maxspeed.value )
		{
			vel.normalize();
			vel *= fb_maxspeed.value;
		}

		this.main.velocity = vel;
		this.collider.velocity = vel;
		this.particles.velocity = vel;
		Vec3 vel_indicator = Vec3(vel);
		vel_indicator.z = 0;
		this.indicator.velocity = vel_indicator;
		@this.groundEntity = null;*/
	}

	void Touch(Entity @ball, Entity @ent, const Vec3 planeNormal, int surfFlags)
	{
		if ( !fb_touch.boolean )
			return;

		if ( ent.entNum == 0 )
			return;

		if ( @ent.client == null )
			return;

		@this.lastHit = @ent.client;

		Vec3 origin = ent.origin;
		origin.z += ent.viewHeight;
		Vec3 dir = touchcollider.origin-origin;
		float distance = dir.normalize();

		Trace tr;
		tr.doTrace(origin, Vec3(), Vec3(), origin + dir * (distance + radius*2), -1, MASK_SHOT);

		Vec3 trdir = touchcollider.origin - tr.endPos;
		float trdist = trdir.length();
		bool hit = false;
		if ( tr.fraction < 1.0 )
		{
			if ( tr.entNum == ball.entNum || trdist < radius*1.1 )
				hit = true;
		}

		float kick = fb_touchminkick.value + fb_touchkick.value * (ent.velocity.length()/fb_touchspeed.value);

		if ( hit )
		{
			trdir.normalize();
			this.Knockback( trdir, kick );
		} else {
			this.Knockback( dir, kick );
		}

		//G_Print("touched by "+ent.classname+" #"+ent.entNum+"\n");
	}

	void Die(Entity @ball, Entity @inflictor, Entity @attacker)
	{
		@this.collider = @G_SpawnEntity("ball_collider");
		this.InitCollider(this.collider);
		this.collider.health = 10000;

		ball.unlinkEntity();
		ball.freeEntity();

		@this.inflictor = @inflictor;
	}
}

void FB_Ball_Pain(Entity @ball, Entity @other, float kick, float damage)
{
	FB_Ball.Pain(@ball, @other, kick, damage);
}

void FB_Ball_Think(Entity @ball)
{
	ball.nextThink = levelTime + 1;
}

void FB_Ball_Touch(Entity @ent, Entity @ball, const Vec3 planeNormal, int surfFlags)
{
	FB_Ball.Touch(@ent, @ball, planeNormal, surfFlags);
}


void FB_Ball_Die(Entity @ent, Entity @inflicter, Entity @attacker)
{
	FB_Ball.Die(@ent, @inflicter, @attacker);
}




void target_goal(Entity @goal)
{
	//@goal.use = FB_Goal_Use;
}

void FB_Goal_Touch(Entity @ent, Entity @ball, const Vec3 planeNormal, int surfFlags)
{
	if ( @ball == @FB_Ball.collider )
	{
		FB_Goal(@ent);
	}
}

void FB_Goal_Think(Entity @ent)
{
	ent.wait -= frameTime;
	ent.nextThink = levelTime + 1;
}

void FB_Goal(Entity @goal)
{
	if ( FB_Ball.scored )
		return;

	//G_Print(goal.targetname+"\n");
	int goal_team = ( goal.target == "goal_alpha" )?TEAM_BETA:TEAM_ALPHA;
	Client@ client = @FB_Ball.lastHit;
	int ball_team = TEAM_PLAYERS;
	if ( @client != null )
		ball_team = client.team;


	goal.wait = 1500;
	Entity@[] goaltargets = goal.findTargets();
	for ( uint i = 0; i < goaltargets.length(); i++ )
	{
		Entity@ goaltarget = @goaltargets[i];
		//G_Print("goaltarget.classname = "+goaltarget.classname+"\n");
		goaltarget.explosionEffect(2048);
		if ( match.getState() == MATCH_STATE_PLAYTIME )
			goaltarget.splashDamage( goaltarget, 4096, 0, 2048, 0, 0 );
		G_PositionedSound( goaltarget.origin, CHAN_AUTO, G_SoundIndex( "sounds/futsball/goal_" + int( brandom( 0, 3 ) ) ), 0 );
	}
	if ( match.getState() == MATCH_STATE_WARMUP )
	{
		FB_Ball.delay = 1000;
	}
	FB_Ball.scored = true;

	if ( match.getState() == MATCH_STATE_PLAYTIME )
	{
		if ( ball_team == TEAM_PLAYERS )
		{
			G_PrintMsg(null, "Something scored for "+((goal_team==TEAM_ALPHA)?"Alpha":"Beta")+"!\n");
		} else if ( goal_team != ball_team )
		{
			G_PrintMsg(null, client.name + " made an Own Goal!\n");
			owngoals[client.playerNum]++;
		} else {
			G_PrintMsg(null, client.name + " Scored for "+((goal_team==TEAM_ALPHA)?"Alpha":"Beta")+"!\n");
			goals[client.playerNum]++;
			client.stats.setScore(goals[client.playerNum]);
		}

		if ( goal_team == TEAM_BETA )
		{
			G_GetTeam(TEAM_BETA).stats.addScore(1);
			int soundIndex = G_SoundIndex( "sounds/futsball/announcer_team_scored" );
			G_AnnouncerSound( null, soundIndex, TEAM_BETA, false, null );
			soundIndex = G_SoundIndex( "sounds/futsball/announcer_enemy_scored" );
			G_AnnouncerSound( null, soundIndex, TEAM_ALPHA, false, null );
		} else {
			G_GetTeam(TEAM_ALPHA).stats.addScore(1);
			int soundIndex = G_SoundIndex( "sounds/futsball/announcer_team_scored" );
			G_AnnouncerSound( null, soundIndex, TEAM_ALPHA, false, null );
			soundIndex = G_SoundIndex( "sounds/futsball/announcer_enemy_scored" );
			G_AnnouncerSound( null, soundIndex, TEAM_BETA, false, null );
		}
		futsball.newRoundState( FB_ROUND_ROUNDFINISHED );
	}

}


void target_boost(Entity @boost)
{
	@boost.use = FB_Boost_Use;
	boost.linkEntity();
}

void FB_Boost_Use(Entity @ent, Entity @other, Entity @activator)
{
	/*G_Print("other = " + other.classname + "\n");
	G_Print("activator = " + activator.classname + "\n");*/
	if ( @activator.client == null )
		return;

	Vec3 mins, maxs;
	other.getSize(mins, maxs);

	Vec3 origin = other.origin + (mins + maxs) * 0.5;

	G_PositionedSound( origin, CHAN_AUTO, G_SoundIndex("sounds/futsball/boost_0.ogg"), 0.25 );


	Vec3 fwd, right, up;
	ent.angles.angleVectors(fwd, right, up);

	@activator.groundEntity = null;

	Vec3 vel = activator.velocity;
	/*vel = fwd * 2000;
	vel.z = 300;*/

	float len = vel.length();
	len += 1000;
	vel.normalize();
	vel *= len;

	activator.velocity = vel;
}