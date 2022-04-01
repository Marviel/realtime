defmodule Ewalrus.DbSupervisor do
  # Automatically defines child_spec/1
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    {:ok, conn} =
      Postgrex.start_link(
        hostname: args[:db_host],
        database: args[:db_name],
        password: args[:db_pass],
        username: args[:db_user],
        queue_target: 3000
      )

    :global.register_name({:db_instance, args[:id]}, conn)

    opts = [
      id: args[:id],
      conn: conn,
      backoff_type: :rand_exp,
      backoff_min: 100,
      backoff_max: 120_000,
      replication_poll_interval: args[:poll_interval],
      publication: args[:publication],
      slot_name: args[:slot_name],
      max_changes: args[:max_changes],
      max_record_bytes: args[:max_record_bytes]
    ]

    children = [
      %{
        id: Ewalrus.ReplicationPoller,
        start: {Ewalrus.ReplicationPoller, :start_link, [opts]},
        restart: :transient
      },
      %{
        id: Ewalrus.SubscriptionManager,
        start: {Ewalrus.SubscriptionManager, :start_link, [%{conn: conn, id: args[:id]}]},
        restart: :transient
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
