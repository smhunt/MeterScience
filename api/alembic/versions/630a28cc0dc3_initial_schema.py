"""Initial schema

Revision ID: 630a28cc0dc3
Revises: 
Create Date: 2025-12-15 23:34:54.108692

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '630a28cc0dc3'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add email_verified column with default False for existing rows
    op.add_column('users', sa.Column('email_verified', sa.Boolean(), nullable=False, server_default='false'))

    # Alter stripe_customer_id to allow longer values
    op.alter_column('users', 'stripe_customer_id',
               existing_type=sa.VARCHAR(length=100),
               type_=sa.String(length=255),
               existing_nullable=True)

    # Add unique constraint on stripe_customer_id
    op.create_unique_constraint('uq_users_stripe_customer_id', 'users', ['stripe_customer_id'])


def downgrade() -> None:
    op.drop_constraint('uq_users_stripe_customer_id', 'users', type_='unique')
    op.alter_column('users', 'stripe_customer_id',
               existing_type=sa.String(length=255),
               type_=sa.VARCHAR(length=100),
               existing_nullable=True)
    op.drop_column('users', 'email_verified')
