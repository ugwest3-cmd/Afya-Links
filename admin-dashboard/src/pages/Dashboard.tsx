

export const Dashboard = () => {
    return (
        <div className="fade-in">
            <h1 className="text-h2" style={{ marginBottom: '2rem' }}>Platform Overview</h1>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '1.5rem' }}>

                <div className="glass-panel" style={{ padding: '1.5rem', borderTop: '4px solid var(--accent-primary)' }}>
                    <p className="text-muted" style={{ fontSize: '0.875rem', fontWeight: 600, textTransform: 'uppercase' }}>Active Pilot Orders</p>
                    <h2 className="text-h1" style={{ marginTop: '0.5rem' }}>Loading...</h2>
                </div>

                <div className="glass-panel" style={{ padding: '1.5rem', borderTop: '4px solid var(--status-success)' }}>
                    <p className="text-muted" style={{ fontSize: '0.875rem', fontWeight: 600, textTransform: 'uppercase' }}>Weekly Commission</p>
                    <h2 className="text-h1" style={{ marginTop: '0.5rem' }}>UGX ---</h2>
                </div>

                <div className="glass-panel" style={{ padding: '1.5rem', borderTop: '4px solid var(--accent-secondary)' }}>
                    <p className="text-muted" style={{ fontSize: '0.875rem', fontWeight: 600, textTransform: 'uppercase' }}>Pending Approvals</p>
                    <h2 className="text-h1" style={{ marginTop: '0.5rem' }}>Loading...</h2>
                </div>

            </div>
        </div>
    );
};
