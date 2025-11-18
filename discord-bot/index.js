import { Client, GatewayIntentBits, EmbedBuilder, ActionRowBuilder, ButtonBuilder, ButtonStyle, SlashCommandBuilder } from 'discord.js';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

// Initialize Supabase
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY
);

// Initialize Discord Client
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
  ],
});

// User session management (Discord ID -> Supabase User ID)
const userSessions = new Map();

// Helper: Create task embed
function createTaskEmbed(task, color = 0xFFA500) {
  const statusEmoji = {
    'unclaimed': '🟠',
    'claimed': '🔵',
    'completed': '🟢'
  };

  const embed = new EmbedBuilder()
    .setTitle(`${statusEmoji[task.status] || '⚪'} Task #${task.id}`)
    .setDescription(task.title)
    .setColor(color)
    .addFields(
      { name: 'Status', value: task.status || 'unclaimed', inline: true },
      { name: 'Priority', value: task.is_urgent ? '🔴 Urgent' : '⚪ Normal', inline: true },
      { name: 'Created', value: new Date(task.created_at).toLocaleDateString(), inline: true }
    );

  if (task.time_of_day) {
    embed.addFields({ name: 'Time', value: task.time_of_day, inline: true });
  }

  return embed;
}

// Helper: Create action buttons
function createTaskButtons(taskId) {
  return new ActionRowBuilder()
    .addComponents(
      new ButtonBuilder()
        .setCustomId(`claim_${taskId}`)
        .setLabel('Claim')
        .setStyle(ButtonStyle.Primary)
        .setEmoji('🔵'),
      new ButtonBuilder()
        .setCustomId(`complete_${taskId}`)
        .setLabel('Complete')
        .setStyle(ButtonStyle.Success)
        .setEmoji('✅'),
      new ButtonBuilder()
        .setCustomId(`urgent_${taskId}`)
        .setLabel('Mark Urgent')
        .setStyle(ButtonStyle.Danger)
        .setEmoji('🔴'),
      new ButtonBuilder()
        .setCustomId(`delete_${taskId}`)
        .setLabel('Delete')
        .setStyle(ButtonStyle.Secondary)
        .setEmoji('🗑️')
    );
}

// Command: Register user
async function registerUser(interaction) {
  const email = interaction.options.getString('email');
  const password = interaction.options.getString('password');
  const name = interaction.options.getString('name');

  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { name }
    }
  });

  if (error) {
    return interaction.reply({ content: `❌ Registration failed: ${error.message}`, ephemeral: true });
  }

  userSessions.set(interaction.user.id, data.user.id);

  const embed = new EmbedBuilder()
    .setTitle('✅ Registration Successful!')
    .setDescription(`Welcome to DuoTask, ${name}!`)
    .setColor(0x00FF00)
    .addFields({ name: 'Email', value: email });

  await interaction.reply({ embeds: [embed], ephemeral: true });
}

// Command: Login user
async function loginUser(interaction) {
  const email = interaction.options.getString('email');
  const password = interaction.options.getString('password');

  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password
  });

  if (error) {
    return interaction.reply({ content: `❌ Login failed: ${error.message}`, ephemeral: true });
  }

  userSessions.set(interaction.user.id, data.user.id);

  const embed = new EmbedBuilder()
    .setTitle('✅ Login Successful!')
    .setDescription('You are now connected to DuoTask')
    .setColor(0x00FF00);

  await interaction.reply({ embeds: [embed], ephemeral: true });
}

// Command: Create task
async function createTask(interaction) {
  const userId = userSessions.get(interaction.user.id);
  if (!userId) {
    return interaction.reply({ content: '❌ Please login first using `/login`', ephemeral: true });
  }

  const title = interaction.options.getString('title');
  const urgent = interaction.options.getBoolean('urgent') || false;

  const { data: task, error } = await supabase
    .from('tasks')
    .insert({
      title,
      status: 'unclaimed',
      is_urgent: urgent,
      created_by: userId
    })
    .select()
    .single();

  if (error) {
    return interaction.reply({ content: `❌ Failed to create task: ${error.message}`, ephemeral: true });
  }

  const embed = createTaskEmbed(task, 0xFFA500);
  const buttons = createTaskButtons(task.id);

  await interaction.reply({ embeds: [embed], components: [buttons] });
}

// Command: List tasks
async function listTasks(interaction) {
  const userId = userSessions.get(interaction.user.id);
  if (!userId) {
    return interaction.reply({ content: '❌ Please login first using `/login`', ephemeral: true });
  }

  const { data: tasks, error } = await supabase
    .from('tasks')
    .select('*')
    .eq('created_by', userId)
    .order('created_at', { ascending: false })
    .limit(10);

  if (error) {
    return interaction.reply({ content: `❌ Failed to fetch tasks: ${error.message}`, ephemeral: true });
  }

  if (!tasks || tasks.length === 0) {
    return interaction.reply({ content: '📭 No tasks found. Create one with `/task`!', ephemeral: true });
  }

  const embed = new EmbedBuilder()
    .setTitle('📋 Your Tasks')
    .setColor(0x5865F2)
    .setDescription(tasks.map(t => 
      `${t.status === 'completed' ? '✅' : t.status === 'claimed' ? '🔵' : '🟠'} **#${t.id}** - ${t.title}`
    ).join('\n'));

  await interaction.reply({ embeds: [embed] });
}

// Command: Generate pairing code
async function generatePairingCode(interaction) {
  const userId = userSessions.get(interaction.user.id);
  if (!userId) {
    return interaction.reply({ content: '❌ Please login first using `/login`', ephemeral: true });
  }

  const code = Math.random().toString(36).substring(2, 8).toUpperCase();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

  const { error } = await supabase
    .from('pairing_codes')
    .insert({
      code,
      initiator_id: userId,
      expires_at: expiresAt.toISOString()
    });

  if (error) {
    return interaction.reply({ content: `❌ Failed to generate code: ${error.message}`, ephemeral: true });
  }

  const embed = new EmbedBuilder()
    .setTitle('🔗 Pairing Code Generated')
    .setDescription(`Your partner can use this code to pair with you`)
    .setColor(0x5865F2)
    .addFields(
      { name: 'Code', value: `\`${code}\``, inline: true },
      { name: 'Expires', value: `<t:${Math.floor(expiresAt.getTime() / 1000)}:R>`, inline: true }
    );

  await interaction.reply({ embeds: [embed], ephemeral: true });
}

// Command: Accept pairing code
async function acceptPairingCode(interaction) {
  const userId = userSessions.get(interaction.user.id);
  if (!userId) {
    return interaction.reply({ content: '❌ Please login first using `/login`', ephemeral: true });
  }

  const code = interaction.options.getString('code').toUpperCase();

  const { data: pairing, error: fetchError } = await supabase
    .from('pairing_codes')
    .select('*')
    .eq('code', code)
    .gt('expires_at', new Date().toISOString())
    .is('used_at', null)
    .single();

  if (fetchError || !pairing) {
    return interaction.reply({ content: '❌ Invalid or expired pairing code', ephemeral: true });
  }

  // Mark code as used
  await supabase
    .from('pairing_codes')
    .update({ used_at: new Date().toISOString(), acceptor_id: userId })
    .eq('code', code);

  const embed = new EmbedBuilder()
    .setTitle('✅ Pairing Successful!')
    .setDescription('You are now paired with your partner. Tasks will sync automatically!')
    .setColor(0x00FF00);

  await interaction.reply({ embeds: [embed], ephemeral: true });
}

// Handle button interactions
async function handleButtonInteraction(interaction) {
  const [action, taskId] = interaction.customId.split('_');
  const userId = userSessions.get(interaction.user.id);

  if (!userId) {
    return interaction.reply({ content: '❌ Please login first', ephemeral: true });
  }

  let updateData = {};
  let message = '';
  let color = 0x5865F2;

  switch (action) {
    case 'claim':
      updateData = { status: 'claimed', claimed_by: userId };
      message = '🔵 Task claimed!';
      color = 0x0099FF;
      break;
    case 'complete':
      updateData = { status: 'completed', completed_at: new Date().toISOString() };
      message = '🎉 Task completed!';
      color = 0x00FF00;
      break;
    case 'urgent':
      updateData = { is_urgent: true };
      message = '🔴 Marked as urgent!';
      color = 0xFF0000;
      break;
    case 'delete':
      await supabase.from('tasks').delete().eq('id', taskId);
      await interaction.update({ content: '🗑️ Task deleted', components: [], embeds: [] });
      return;
  }

  const { data: task, error } = await supabase
    .from('tasks')
    .update(updateData)
    .eq('id', taskId)
    .select()
    .single();

  if (error) {
    return interaction.reply({ content: `❌ Failed: ${error.message}`, ephemeral: true });
  }

  const embed = createTaskEmbed(task, color);
  const buttons = createTaskButtons(task.id);

  await interaction.update({ content: message, embeds: [embed], components: [buttons] });
}

// Register slash commands
const commands = [
  new SlashCommandBuilder()
    .setName('register')
    .setDescription('Create a DuoTask account')
    .addStringOption(option => option.setName('email').setDescription('Your email').setRequired(true))
    .addStringOption(option => option.setName('password').setDescription('Your password').setRequired(true))
    .addStringOption(option => option.setName('name').setDescription('Your name').setRequired(true)),
  
  new SlashCommandBuilder()
    .setName('login')
    .setDescription('Login to DuoTask')
    .addStringOption(option => option.setName('email').setDescription('Your email').setRequired(true))
    .addStringOption(option => option.setName('password').setDescription('Your password').setRequired(true)),
  
  new SlashCommandBuilder()
    .setName('task')
    .setDescription('Create a new task')
    .addStringOption(option => option.setName('title').setDescription('Task description').setRequired(true))
    .addBooleanOption(option => option.setName('urgent').setDescription('Mark as urgent')),
  
  new SlashCommandBuilder()
    .setName('list')
    .setDescription('View your tasks'),
  
  new SlashCommandBuilder()
    .setName('pair')
    .setDescription('Generate a pairing code'),
  
  new SlashCommandBuilder()
    .setName('accept')
    .setDescription('Accept a pairing code')
    .addStringOption(option => option.setName('code').setDescription('6-character pairing code').setRequired(true)),
];

// Bot ready event
client.once('ready', async () => {
  console.log(`✅ Logged in as ${client.user.tag}`);
  
  // Register slash commands
  try {
    console.log('📝 Registering slash commands...');
    await client.application.commands.set(commands);
    console.log('✅ Slash commands registered!');
  } catch (error) {
    console.error('❌ Failed to register commands:', error);
  }
});

// Handle slash commands
client.on('interactionCreate', async interaction => {
  if (interaction.isChatInputCommand()) {
    switch (interaction.commandName) {
      case 'register':
        await registerUser(interaction);
        break;
      case 'login':
        await loginUser(interaction);
        break;
      case 'task':
        await createTask(interaction);
        break;
      case 'list':
        await listTasks(interaction);
        break;
      case 'pair':
        await generatePairingCode(interaction);
        break;
      case 'accept':
        await acceptPairingCode(interaction);
        break;
    }
  } else if (interaction.isButton()) {
    await handleButtonInteraction(interaction);
  }
});

// Login to Discord
client.login(process.env.DISCORD_TOKEN);
