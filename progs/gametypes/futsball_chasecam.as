ChaseCam[] chaseCams(maxClients);

const int CHASE_NONE = 0;
const int CHASE_FREE = 1;
const int CHASE_FIXED = 2;
const int CHASE_FOLLOW = 3;
const int CHASE_RESET = 4;

class ChaseCam
{
	Client@ client;
	Entity@ player;
	uint chase_timestamp = 0;
	bool chase_pressed = false;
	int chase_state;

	ChaseCam()
	{
		this.chase_state = CHASE_NONE;
	}
	~ChaseCam(){}

	void Update()
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

String boolstr(bool a)
{
	if ( a )
		return "true";
	else
		return "false";
}