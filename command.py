from execution import joint_state_control
from pybullet_tools.utils import set_joint_positions, create_attachment, wait_for_duration, user_input
from utils import get_descendant_obstacles

import time


class State(object):
    def __init__(self, savers=[], attachments=[]):
        # a part of the state separate from pybullet
        self.savers = tuple(savers)
        self.attachments = {attachment.child: attachment for attachment in attachments}
    @property
    def bodies(self):
        return {saver.body for saver in self.savers} | set(self.attachments)
    def derive(self):
        for attachment in self.attachments.values():
            # Derived values
            # TODO: topological sort
            attachment.assign()
    def assign(self):
        for saver in self.savers:
            saver.restore()
        self.derive()
    def __repr__(self):
        return '{}({}, {})'.format(self.__class__.__name__, list(self.savers), self.attachments)
    # TODO: copy?

class Command(object):
    def __init__(self, world):
        self.world = world

    @property
    def bodies(self):
        raise NotImplementedError()

    def reverse(self):
        raise NotImplementedError()

    def iterate(self, world, state):
        raise NotImplementedError()

    def execute(self, domain, world_state, observer):
        raise NotImplementedError()

class Sequence(object):
    def __init__(self, context, commands=[]):
        self.context = context
        self.commands = tuple(commands)
    @property
    def bodies(self):
        bodies = set(self.context.bodies)
        for command in self.commands:
            bodies.update(command.bodies)
        return bodies
    def reverse(self):
        return Sequence(self.context, [command.reverse() for command in reversed(self.commands)])
    def __repr__(self):
        #return '[{}]'.format('->'.join(map(repr, self.commands)))
        return '{}({})'.format(self.__class__.__name__, len(self.commands))

################################################################################

class Trajectory(Command):
    def __init__(self, world, robot, joints, path):
        super(Trajectory, self).__init__(world)
        self.robot = robot
        self.joints = tuple(joints)
        self.path = tuple(path)

    @property
    def bodies(self):
        return {self.robot}

    def reverse(self):
        return self.__class__(self.world, self.robot, self.joints, self.path[::-1])

    def iterate(self, world, state):
        for positions in self.path:
            set_joint_positions(self.robot, self.joints, positions)
            yield

    def execute(self, domain, moveit, observer): # TODO: actor
        robot_entity = domain.get_robot()
        if len(robot_entity.joints) != len(self.joints):
            # TODO: ensure the same joint names
            # TODO: allow partial gripper closures
            return
        status = joint_state_control(self.robot, self.joints, self.path, domain, moveit, observer)
        time.sleep(1.0)
        return status

    def __repr__(self):
        return '{}({}x{})'.format(self.__class__.__name__, len(self.joints), len(self.path))

class DoorTrajectory(Command):
    def __init__(self, world, robot, robot_joints, robot_path,
                 door, door_joints, door_path):
        super(DoorTrajectory, self).__init__(world)
        self.robot = robot
        self.robot_joints = tuple(robot_joints)
        self.robot_path = tuple(robot_path)
        self.door = door
        self.door_joints = tuple(door_joints)
        self.door_path = tuple(door_path)
        assert len(self.robot_path) == len(self.door_path)

    @property
    def bodies(self):
        return {self.robot} | get_descendant_obstacles(self.world.kitchen, self.door_joints[0])

    def reverse(self):
        return self.__class__(self.world, self.robot, self.robot_joints, self.robot_path[::-1],
                              self.door, self.door_joints, self.door_path[::-1])

    def iterate(self, world, state):
        for robot_conf, door_conf in zip(self.robot_path, self.door_path):
            set_joint_positions(self.robot, self.robot_joints, robot_conf)
            set_joint_positions(self.door, self.door_joints, door_conf)
            yield

    def execute(self, domain, moveit, observer):
        #robot_entity = domain.get_robot()
        #franka = robot_entity.robot
        #for positions in self.robot_path:
        #    franka.end_effector.go_config(positions)
        # TODO: only sleep is used by close_gripper and open_gripper...
        #moveit.close_gripper(controllable_object=None, speed=0.1, force=40., sleep=0.2, wait=True)
        time.sleep(1.0)
        status = joint_state_control(self.robot, self.robot_joints, self.robot_path, domain, moveit, observer)
        time.sleep(1.0)
        moveit.open_gripper(speed=0.1, sleep=0.2, wait=True)
        time.sleep(1.0)
        return status

    def __repr__(self):
        return '{}({}x{})'.format(self.__class__.__name__, len(self.robot_joints) + len(self.door_joints),
                                  len(self.robot_path))

################################################################################s

class Attach(Command):
    def __init__(self, world, robot, link, body):
        # TODO: names or bodies?
        super(Attach, self).__init__(world)
        self.robot = robot
        self.link = link
        self.body = body

    @property
    def bodies(self):
        return {self.robot, self.body}

    def reverse(self):
        return Detach(self.world, self.robot, self.link, self.body)

    def iterate(self, world, state):
        state.attachments[self.body] = create_attachment(self.robot, self.link, self.body)
        yield

    def execute(self, domain, moveit, observer):
        # controllable_object is not needed for joint positions
        moveit.close_gripper(controllable_object=None, speed=0.1, force=40., sleep=0.2, wait=True)
        # TODO: attach_obj
        #robot_entity = domain.get_robot()
        #franka = robot_entity.robot
        #gripper = franka.end_effector.gripper
        #gripper.close(attach_obj=None, speed=.2, force=40., actuate_gripper=True, wait=True)
        #update_robot(self.world, domain, observer, observer.observe())
        #time.sleep(1.0)

    def __repr__(self):
        return '{}({})'.format(self.__class__.__name__, self.world.get_name(self.body))

class Detach(Command):
    def __init__(self, world, robot, link, body):
        super(Detach, self).__init__(world)
        self.robot = robot
        self.link = link
        self.body = body

    @property
    def bodies(self):
        return {self.robot, self.body}

    def reverse(self):
        return Attach(self.world, self.robot, self.link, self.body)

    def iterate(self, world, state):
        assert self.body in state.attachments
        del state.attachments[self.body]
        yield

    def execute(self, domain, moveit, observer):
        moveit.open_gripper(speed=0.1, sleep=0.2, wait=True)
        #robot_entity = domain.get_robot()
        #franka = robot_entity.robot
        #gripper = franka.end_effector.gripper
        #gripper.open(speed=.2, actuate_gripper=True, wait=True)
        #update_robot(self.world, domain, observer.observe())
        #time.sleep(1.0)

    def __repr__(self):
        return '{}({})'.format(self.__class__.__name__, self.world.get_name(self.body))

class Wait(Command):
    def __init__(self, world, steps):
        super(Wait, self).__init__(world)
        self.steps = steps

    @property
    def bodies(self):
        return {}

    def reverse(self):
        return self

    def iterate(self, world, state):
        for _ in range(self.steps):
            yield

    def execute(self, domain, moveit, observer):
        pass

    def __repr__(self):
        return '{}({})'.format(self.__class__.__name__, self.steps)

# TODO: cook that includes a wait

################################################################################s

def execute_plan(world, state, commands, time_step=None):
    for i, command in enumerate(commands):
        print('\nCommand {:2}: {}'.format(i, command))
        # TODO: skip to end
        # TODO: downsample
        for j, _ in enumerate(command.iterate(world, state)):
            state.derive()
            if j == 0:
                continue
            if time_step is None:
                wait_for_duration(1e-2)
                user_input('Command {:2} | step {:2} | Next?'.format(i, j))
            else:
                wait_for_duration(time_step)